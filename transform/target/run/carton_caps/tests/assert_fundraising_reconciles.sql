
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  -- Dollars raised must agree from silver through every gold layer that reports them.
with totals as (
    select 'silver valid purchases' as source,
           cast(round(sum(points_expected) / 100, 2) as decimal(18, 2)) as dollars
    from "carton_caps"."silver"."int_purchases_checked" where dq_status = 'valid'
    union all
    select 'fct_purchases', sum(dollars_raised) from "carton_caps"."gold"."fct_purchases"
    union all
    select 'school_daily_activity', sum(dollars_raised) from "carton_caps"."gold"."school_daily_activity"
    union all
    select 'school_engagement_monthly', sum(dollars_raised) from "carton_caps"."gold"."school_engagement_monthly"
    union all
    select 'product_category_monthly', sum(dollars_raised) from "carton_caps"."gold"."product_category_monthly"
    union all
    select 'spending_by_segment', sum(dollars_raised) from "carton_caps"."gold"."spending_by_segment"
)

select *
from totals
where abs(dollars - (select dollars from totals where source = 'fct_purchases')) > 0.01
  
  
      
    ) dbt_internal_test