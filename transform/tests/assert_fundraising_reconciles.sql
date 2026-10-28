-- Dollars raised must agree from silver through every gold layer that reports them.
with totals as (
    select 'silver valid purchases' as source,
           {{ points_to_dollars('sum(points_expected)') }} as dollars
    from {{ ref('purchases_checked') }} where dq_status = 'valid'
    union all
    select 'fct_purchases', sum(dollars_raised) from {{ ref('fct_purchases') }}
    union all
    select 'school_daily_activity', sum(dollars_raised) from {{ ref('school_daily_activity') }}
    union all
    select 'school_engagement_monthly', sum(dollars_raised) from {{ ref('school_engagement_monthly') }}
    union all
    select 'product_category_monthly', sum(dollars_raised) from {{ ref('product_category_monthly') }}
    union all
    select 'spending_by_segment', sum(dollars_raised) from {{ ref('spending_by_segment') }}
)

select *
from totals
where abs(dollars - (select dollars from totals where source = 'fct_purchases')) > 0.01
