-- One row per valid purchase (one product, any quantity).
select
    p.purchase_id,
    p.user_id,
    u.school_id,
    u.user_type,
    u.acquisition_channel,
    p.product_id,
    pr.category,
    p.purchased_at,
    cast(p.purchased_at as date)                         as purchase_date,
    cast(date_trunc('month', p.purchased_at) as date)    as purchase_month,
    dayname(p.purchased_at)                              as day_name,
    isodow(p.purchased_at)                               as day_of_week_number,
    hour(p.purchased_at)                                 as hour_of_day,
    p.quantity,
    round(pr.list_price * p.quantity, 2)                 as list_amount,
    p.price_paid,
    round(pr.list_price * p.quantity, 2) - p.price_paid  as discount_amount,
    p.price_paid < round(pr.list_price * p.quantity, 2)  as is_promo,
    p.points_expected                                    as points_earned,   -- repaired by rule
    p.points_reported,                                                       -- as sent by the app
    {{ points_to_dollars('p.points_expected') }}         as dollars_raised
from {{ ref('purchases_checked') }} as p
inner join {{ ref('dim_users') }} as u on u.user_id = p.user_id
inner join {{ ref('dim_products') }} as pr on pr.product_id = p.product_id
where p.dq_status = 'valid'
