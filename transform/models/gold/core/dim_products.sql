select
    product_id,
    product_name,
    category,
    list_price,
    points_per_dollar,
    launched_at
from {{ ref('products_current') }}
