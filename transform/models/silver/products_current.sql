-- Current product catalog: the latest snapshot, typed.
with latest as (
    select *
    from {{ source('bronze', 'products') }}
    where _batch_id = (select max(_batch_id) from {{ source('bronze', 'products') }})
)

select
    try_cast(product_id as integer)           as product_id,
    nullif(trim(name), '')                    as product_name,
    nullif(trim(category), '')                as category,
    try_cast(price as decimal(10, 2))         as list_price,
    try_cast(points_per_dollar as integer)    as points_per_dollar,
    try_cast(created_at as timestamp)         as launched_at,
    _batch_id                                 as snapshot_batch_id
from latest
