
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select cohort_month, channel, months_since_signup, count(*) as n
    from "carton_caps"."gold"."cohort_retention"
    group by cohort_month, channel, months_since_signup
    having count(*) > 1

  
  
      
    ) dbt_internal_test