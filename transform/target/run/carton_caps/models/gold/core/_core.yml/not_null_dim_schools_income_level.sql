
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select income_level
from "carton_caps"."gold"."dim_schools"
where income_level is null



  
  
      
    ) dbt_internal_test