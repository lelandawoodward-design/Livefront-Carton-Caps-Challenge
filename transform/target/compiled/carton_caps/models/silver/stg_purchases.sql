

-- Every bronze purchase row, typed. One row per arrival (duplicates included);
-- int_purchases_checked collapses and validates them.
with typed as (
    select
        try_cast(purchase_id as bigint)            as purchase_id,
        try_cast(user_id as integer)               as user_id,
        try_cast(product_id as integer)            as product_id,
        try_cast(quantity as integer)              as quantity,
        try_cast(price_paid as decimal(12, 2))     as price_paid,
        try_cast(points_earned as integer)         as points_reported,
        try_cast(purchased_at as timestamp)        as purchased_at,
        nullif(trim(day_of_week), '')              as day_of_week_reported,
        try_cast(hour_of_day as integer)           as hour_of_day_reported,
        md5(concat_ws('|',
            coalesce(purchase_id, '~'), coalesce(user_id, '~'), coalesce(product_id, '~'),
            coalesce(quantity, '~'), coalesce(price_paid, '~'), coalesce(points_earned, '~'),
            coalesce(purchased_at, '~'), coalesce(day_of_week, '~'), coalesce(hour_of_day, '~')
        ))                                         as content_hash,
        _batch_id,
        _row_number,
        _source_file
    from "carton_caps"."bronze"."purchases"
)

select
    -- Rows whose id can't be parsed still need a stable key so they can be quarantined.
    coalesce(cast(purchase_id as varchar), 'unparsed:' || _source_file || ':' || _row_number) as record_key,
    *,
    -- What a client retry would repeat: everything except the id.
    case when user_id is not null and product_id is not null and purchased_at is not null
              and quantity is not null and price_paid is not null
         then md5(concat_ws('|', user_id, product_id, purchased_at, quantity, price_paid))
    end as natural_key
from typed