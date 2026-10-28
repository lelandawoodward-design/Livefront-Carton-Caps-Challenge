

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



 __dbt__cte__stg_purchases as (

-- Fixture for stg_purchases
select 
    
    cast('1' as character varying)
 as "record_key", 
    
    cast(1 as BIGINT)
 as "purchase_id", 
    
    cast(10 as INTEGER)
 as "user_id", 
    
    cast(100 as INTEGER)
 as "product_id", 
    
    cast(2 as INTEGER)
 as "quantity", 
    
    cast(10.0 as DECIMAL(12,2))
 as "price_paid", 
    
    cast(20 as INTEGER)
 as "points_reported", 
    
    cast('2024-01-05 10:00:00' as TIMESTAMP)
 as "purchased_at", 
    
    cast('Friday' as character varying)
 as "day_of_week_reported", 
    
    cast(10 as INTEGER)
 as "hour_of_day_reported", 
    
    cast('a' as character varying)
 as "content_hash", 
    
    cast('2024-01-31' as DATE)
 as "_batch_id", 
    
    cast(1 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file", 
    
    cast('n1' as character varying)
 as "natural_key"
union all
select 
    
    cast('1' as character varying)
 as "record_key", 
    
    cast(1 as BIGINT)
 as "purchase_id", 
    
    cast(10 as INTEGER)
 as "user_id", 
    
    cast(100 as INTEGER)
 as "product_id", 
    
    cast(2 as INTEGER)
 as "quantity", 
    
    cast(10.0 as DECIMAL(12,2))
 as "price_paid", 
    
    cast(20 as INTEGER)
 as "points_reported", 
    
    cast('2024-01-05 10:00:00' as TIMESTAMP)
 as "purchased_at", 
    
    cast('Friday' as character varying)
 as "day_of_week_reported", 
    
    cast(10 as INTEGER)
 as "hour_of_day_reported", 
    
    cast('a' as character varying)
 as "content_hash", 
    
    cast('2024-01-31' as DATE)
 as "_batch_id", 
    
    cast(2 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file", 
    
    cast('n1' as character varying)
 as "natural_key"
union all
select 
    
    cast('2' as character varying)
 as "record_key", 
    
    cast(2 as BIGINT)
 as "purchase_id", 
    
    cast(10 as INTEGER)
 as "user_id", 
    
    cast(100 as INTEGER)
 as "product_id", 
    
    cast(2 as INTEGER)
 as "quantity", 
    
    cast(10.0 as DECIMAL(12,2))
 as "price_paid", 
    
    cast(20 as INTEGER)
 as "points_reported", 
    
    cast('2024-01-05 10:00:00' as TIMESTAMP)
 as "purchased_at", 
    
    cast('Friday' as character varying)
 as "day_of_week_reported", 
    
    cast(10 as INTEGER)
 as "hour_of_day_reported", 
    
    cast('b' as character varying)
 as "content_hash", 
    
    cast('2024-01-31' as DATE)
 as "_batch_id", 
    
    cast(3 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file", 
    
    cast('n1' as character varying)
 as "natural_key"
union all
select 
    
    cast('3' as character varying)
 as "record_key", 
    
    cast(3 as BIGINT)
 as "purchase_id", 
    
    cast(10 as INTEGER)
 as "user_id", 
    
    cast(100 as INTEGER)
 as "product_id", 
    
    cast(1 as INTEGER)
 as "quantity", 
    
    cast(4.99 as DECIMAL(12,2))
 as "price_paid", 
    
    cast(30 as INTEGER)
 as "points_reported", 
    
    cast('2024-01-06 11:00:00' as TIMESTAMP)
 as "purchased_at", 
    
    cast('Saturday' as character varying)
 as "day_of_week_reported", 
    
    cast(11 as INTEGER)
 as "hour_of_day_reported", 
    
    cast('c' as character varying)
 as "content_hash", 
    
    cast('2024-01-31' as DATE)
 as "_batch_id", 
    
    cast(4 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file", 
    
    cast('n3' as character varying)
 as "natural_key"
union all
select 
    
    cast('4' as character varying)
 as "record_key", 
    
    cast(4 as BIGINT)
 as "purchase_id", 
    
    cast(10 as INTEGER)
 as "user_id", 
    
    cast(999 as INTEGER)
 as "product_id", 
    
    cast(1 as INTEGER)
 as "quantity", 
    
    cast(5.0 as DECIMAL(12,2))
 as "price_paid", 
    
    cast(5 as INTEGER)
 as "points_reported", 
    
    cast('2024-01-07 12:00:00' as TIMESTAMP)
 as "purchased_at", 
    
    cast('Sunday' as character varying)
 as "day_of_week_reported", 
    
    cast(12 as INTEGER)
 as "hour_of_day_reported", 
    
    cast('d' as character varying)
 as "content_hash", 
    
    cast('2024-01-31' as DATE)
 as "_batch_id", 
    
    cast(5 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file", 
    
    cast('n4' as character varying)
 as "natural_key"
union all
select 
    
    cast('5' as character varying)
 as "record_key", 
    
    cast(5 as BIGINT)
 as "purchase_id", 
    
    cast(10 as INTEGER)
 as "user_id", 
    
    cast(100 as INTEGER)
 as "product_id", 
    
    cast(1 as INTEGER)
 as "quantity", 
    
    cast(5.0 as DECIMAL(12,2))
 as "price_paid", 
    
    cast(10 as INTEGER)
 as "points_reported", 
    
    cast('2023-12-01 09:00:00' as TIMESTAMP)
 as "purchased_at", 
    
    cast('Friday' as character varying)
 as "day_of_week_reported", 
    
    cast(9 as INTEGER)
 as "hour_of_day_reported", 
    
    cast('e' as character varying)
 as "content_hash", 
    
    cast('2024-01-31' as DATE)
 as "_batch_id", 
    
    cast(6 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file", 
    
    cast('n5' as character varying)
 as "natural_key"
),  __dbt__cte__stg_products as (

-- Fixture for stg_products
select 
    
    cast(100 as INTEGER)
 as "product_id", cast(null as character varying(256)) as "product_name", cast(null as character varying(256)) as "category", 
    
    cast(5.0 as DECIMAL(10,2))
 as "list_price", 
    
    cast(2 as INTEGER)
 as "points_per_dollar", cast(null as TIMESTAMP) as "launched_at", cast(null as DATE) as "snapshot_batch_id"
),  __dbt__cte__stg_users as (

-- Fixture for stg_users
select 
    
    cast(10 as INTEGER)
 as "user_id", cast(null as INTEGER) as "school_id", cast(null as character varying(256)) as "user_type", 
    
    cast('2024-01-01 08:00:00' as TIMESTAMP)
 as "signup_at", cast(null as character varying(256)) as "email_hash", cast(null as BOOLEAN) as "has_shared_email", cast(null as VARCHAR[]) as "dq_issues", cast(null as character varying(256)) as "dq_issues_text", 
    
    cast('valid' as character varying)
 as "dq_status", cast(null as DATE) as "first_seen_batch_id", cast(null as DATE) as "snapshot_batch_id"
),  __dbt__cte__dq_check_catalog as (

-- Fixture for dq_check_catalog
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('unparseable_or_missing' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('A key, timestamp, quantity or amount is missing or cannot be parsed' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('conflicting_duplicate' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The same purchase_id arrived with different content' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('exact_duplicate' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('drop_extra_copies' as character varying)
 as "action", 
    
    cast('The same purchase_id arrived more than once with identical content (replayed upload); one copy is kept' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('retry_duplicate' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Same user, product, timestamp, quantity and amount as an earlier purchase_id (client retry)' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('orphan_product' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('product_id is not in the product catalog' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('orphan_user' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('user_id is not in users (re-checked every run in case the user arrives later)' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('user_quarantined' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The purchasing user is quarantined' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('non_positive_quantity' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Quantity is zero or negative' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('price_out_of_range' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('price_paid is not positive, exceeds the list amount, or is below min_price_ratio of it' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('before_signup' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Purchased before the user signed up' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('future_timestamp' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Purchased after the cutoff of the batch it arrived in' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('points_mismatch' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('repair' as character varying)
 as "action", 
    
    cast('points_earned differs from floor(price_paid x points_per_dollar); the rule value is used' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('derived_field_mismatch' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('repair' as character varying)
 as "action", 
    
    cast('day_of_week or hour_of_day disagree with purchased_at; recomputed from the timestamp' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('unparseable_or_missing' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('referral_id, referrer, sent_at or status is missing or cannot be parsed' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('conflicting_duplicate' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The same referral_id arrived twice in one batch with different content' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('invalid_status' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('status is not sent, clicked or converted' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('orphan_referrer' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The referrer is not a valid user' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('unknown_referred_user' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('referred_user_id is not in users' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('self_referral' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The invited email is the referrer''s own (after normalising case and +tags)' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('status_inconsistent' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Status converted without a referred user and converted_at (or the reverse)' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('existing_member' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Converted to someone who was already a member when the invite was sent' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('converted_before_sent' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('converted_at is earlier than sent_at' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('duplicate_send' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Same referrer invited the same email within duplicate_send_window_hours; the later invite is quarantined' as character varying)
 as "description"
union all
select 
    
    cast('users' as character varying)
 as "entity", 
    
    cast('unparseable_or_missing' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('user_id or created_at is missing or cannot be parsed' as character varying)
 as "description"
union all
select 
    
    cast('users' as character varying)
 as "entity", 
    
    cast('orphan_school' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('school_id is not in schools' as character varying)
 as "description"
union all
select 
    
    cast('users' as character varying)
 as "entity", 
    
    cast('invalid_user_type' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('user_type is not parent, teacher or supporter' as character varying)
 as "description"
union all
select 
    
    cast('users' as character varying)
 as "entity", 
    
    cast('shared_email' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('flag' as character varying)
 as "action", 
    
    cast('Another user has the same email; joins never use email' as character varying)
 as "description"
),  __dbt__cte__meta__ingested_files as (

-- Fixture for ingested_files
select cast(null as character varying(256)) as "file_path", 
    
    cast('2024-02-29' as DATE)
 as "batch_id", cast(null as character varying(256)) as "entity", cast(null as character varying(256)) as "sha256", cast(null as BIGINT) as "row_count", cast(null as TIMESTAMP) as "ingested_at"
), versions as (
    select *
    from __dbt__cte__stg_purchases
    
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
    left join __dbt__cte__stg_products as p on p.product_id = c.product_id
    left join __dbt__cte__stg_users as u on u.user_id = c.user_id
    left join first_by_natural_key as k on k.natural_key = c.natural_key
)

select
    *,
    array_to_string(dq_issues, ', ')          as dq_issues_text,
    case
        when list_has_any(dq_issues, (
            select list(check_name) from __dbt__cte__dq_check_catalog
            where entity = 'purchases' and action = 'quarantine'
        )) then 'quarantined'
        else 'valid'
    end as dq_status,
    (select max(batch_id) from __dbt__cte__meta__ingested_files)                   as evaluated_batch_id  -- the run that last (re)checked this record
from checked