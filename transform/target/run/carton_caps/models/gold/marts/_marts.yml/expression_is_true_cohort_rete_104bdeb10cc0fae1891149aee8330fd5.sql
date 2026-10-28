
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select * from "carton_caps"."gold"."cohort_retention" where not coalesce((retention_rate between 0 and 1), false)

  
  
      
    ) dbt_internal_test