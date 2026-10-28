
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select * from "carton_caps"."silver"."stg_districts" where not coalesce((median_household_income > 0), false)

  
  
      
    ) dbt_internal_test