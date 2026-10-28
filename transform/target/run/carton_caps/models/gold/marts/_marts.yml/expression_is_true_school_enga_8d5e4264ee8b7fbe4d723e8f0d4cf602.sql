
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select * from "carton_caps"."gold"."school_engagement_monthly" where not coalesce((stickiness is null or stickiness between 0 and 1), false)

  
  
      
    ) dbt_internal_test