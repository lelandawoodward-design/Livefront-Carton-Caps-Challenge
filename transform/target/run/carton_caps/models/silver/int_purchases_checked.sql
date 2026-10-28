
    

    create  table
      "carton_caps"."silver"."int_purchases_checked"
  
    
    as (
      

-- One row per purchase record with its data-quality verdict (dq_issues, dq_status).
--
-- Incremental runs re-evaluate three sets of records:
--   1. records that arrived in a new batch
--   2. records currently quarantined, so a user who arrives later can release
--      or re-classify them (late-arriving dimension)
--   3. existing records that share a natural key with a new record, so client
--      retries are judged across batches
-- Every raw version of a re-evaluated record is read again from stg_purchases,
-- which keeps an incremental build identical to a full rebuild.

with



versions as (
    select *
    from "carton_caps"."silver"."stg_purchases"
    
),

version_stats as (
    select
        record_key,
        count(*)                     as copies,
        count(distinct content_hash) as distinct_versions,
        min(_batch_id)               as first_batch_id,
        max(_batch_id)               as last_batch_id
    from versions
    group by record_key
),

-- The first arrival represents the record.
candidates as (
    select v.*, s.copies, s.distinct_versions, s.first_batch_id, s.last_batch_id
    from versions as v
    inner join version_stats as s on s.record_key = v.record_key
    qualify row_number() over (partition by v.record_key order by v._batch_id, v._row_number) = 1
),

-- Every record sharing a natural key with a candidate, including untouched existing ones.
natural_key_peers as (
    select natural_key, purchase_id
    from candidates
    where natural_key is not null
    
),

first_by_natural_key as (
    select natural_key, min(purchase_id) as first_purchase_id
    from natural_key_peers
    group by natural_key
),

checked as (
    select
        c.record_key,
        c.purchase_id,
        c.user_id,
        c.product_id,
        c.quantity,
        c.price_paid,
        c.points_reported,
        cast(floor(round(c.price_paid * p.points_per_dollar, 6)) as integer) as points_expected,
        c.purchased_at,
        c.natural_key,
        c.copies,
        c.first_batch_id,
        c.last_batch_id,
        list_filter([
            case when c.purchase_id is null or c.user_id is null or c.product_id is null
                      or c.purchased_at is null or c.quantity is null or c.price_paid is null
                 then 'unparseable_or_missing' end,
            case when c.distinct_versions > 1 then 'conflicting_duplicate' end,
            case when c.copies > 1 and c.distinct_versions = 1 then 'exact_duplicate' end,
            case when c.purchase_id > k.first_purchase_id then 'retry_duplicate' end,
            case when c.product_id is not null and p.product_id is null then 'orphan_product' end,
            case when c.user_id is not null and u.user_id is null then 'orphan_user' end,
            case when u.dq_status = 'quarantined' then 'user_quarantined' end,
            case when c.quantity <= 0 then 'non_positive_quantity' end,
            case when c.quantity > 0 and p.list_price is not null
                      and (c.price_paid <= 0
                           or c.price_paid > round(p.list_price * c.quantity, 2) + 0.01
                           or c.price_paid < p.list_price * c.quantity * 0.5)
                 then 'price_out_of_range' end,
            case when c.purchased_at < u.signup_at then 'before_signup' end,
            case when c.purchased_at >= c.first_batch_id + interval 1 day then 'future_timestamp' end,
            case when c.quantity > 0 and p.points_per_dollar is not null
                      and c.points_reported is distinct from
                          cast(floor(round(c.price_paid * p.points_per_dollar, 6)) as integer)
                 then 'points_mismatch' end,
            case when c.purchased_at is not null
                      and (c.day_of_week_reported is distinct from dayname(c.purchased_at)
                           or c.hour_of_day_reported is distinct from hour(c.purchased_at))
                 then 'derived_field_mismatch' end
        ], lambda x: x is not null) as dq_issues
    from candidates as c
    left join "carton_caps"."silver"."stg_products" as p on p.product_id = c.product_id
    left join "carton_caps"."silver"."stg_users" as u on u.user_id = c.user_id
    left join first_by_natural_key as k on k.natural_key = c.natural_key
)

select
    *,
    array_to_string(dq_issues, ', ')          as dq_issues_text,
    case
        when list_has_any(dq_issues, (
            select list(check_name) from "carton_caps"."quality"."dq_check_catalog"
            where entity = 'purchases' and action = 'quarantine'
        )) then 'quarantined'
        else 'valid'
    end as dq_status,
    (select max(batch_id) from "carton_caps"."meta"."ingested_files")                   as evaluated_batch_id  -- the run that last (re)checked this record
from checked
    );
    
  
  