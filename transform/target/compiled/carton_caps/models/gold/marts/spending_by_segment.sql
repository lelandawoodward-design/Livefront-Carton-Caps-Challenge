-- Spending by school-district income level and user type: how much each group
-- buys, what it pays per purchase, how often it uses promotions, and what it raises.
with users as (
    select u.user_id, u.user_type, s.income_level
    from "carton_caps"."gold"."dim_users" as u
    inner join "carton_caps"."gold"."dim_schools" as s on s.school_id = u.school_id
),

per_user as (
    select
        user_id,
        count(*)                              as purchases,
        sum(quantity)                         as units,
        sum(list_amount)                      as list_amount,
        sum(price_paid)                       as spend,
        count(*) filter (where is_promo)      as promo_purchases,
        sum(dollars_raised)                   as dollars_raised
    from "carton_caps"."gold"."fct_purchases"
    group by all
)

select
    u.income_level,
    u.user_type,
    count(*)                                                          as users,
    count(p.user_id)                                                  as buying_users,
    coalesce(sum(p.purchases), 0)                                     as purchases,
    round(sum(p.purchases) / nullif(count(p.user_id), 0), 2)          as purchases_per_buyer,
    round(sum(p.units) / nullif(sum(p.purchases), 0), 2)              as units_per_purchase,
    round(sum(p.list_amount) / nullif(sum(p.units), 0), 2)            as avg_list_price_per_unit,
    round(sum(p.spend) / nullif(sum(p.purchases), 0), 2)              as spend_per_purchase,
    round(sum(p.spend) / nullif(count(p.user_id), 0), 2)              as spend_per_buyer,
    round(sum(p.promo_purchases) / nullif(sum(p.purchases), 0), 4)    as promo_share,
    coalesce(sum(p.spend), 0)                                         as spend,
    coalesce(sum(p.dollars_raised), 0)                                as dollars_raised,
    round(coalesce(sum(p.dollars_raised), 0) / count(*), 2)           as dollars_raised_per_user
from users as u
left join per_user as p on p.user_id = u.user_id
group by all