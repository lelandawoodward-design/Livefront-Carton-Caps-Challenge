
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select sent_month, referrer_segment, count(*) as n
    from "carton_caps"."gold"."referral_funnel_monthly"
    group by sent_month, referrer_segment
    having count(*) > 1

  
  
      
    ) dbt_internal_test