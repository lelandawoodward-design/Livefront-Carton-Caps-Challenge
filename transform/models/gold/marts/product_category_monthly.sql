-- Category performance by month and user type, with share of spend and month-over-month growth.
with monthly as (
    select
        purchase_month          as month,
        category,
        user_type,
        count(*)                as purchases,
        sum(quantity)           as units,
        sum(price_paid)         as spend,
        count(distinct user_id) as buyers,
        sum(dollars_raised)     as dollars_raised
    from {{ ref('fct_purchases') }}
    group by all
)

select
    *,
    round(spend / sum(spend) over (partition by month, user_type), 4) as share_of_user_type_spend,
    round(spend / nullif(lag(spend) over (partition by category, user_type order by month), 0) - 1, 4)
                                                                     as spend_growth_vs_prior_month
from monthly
