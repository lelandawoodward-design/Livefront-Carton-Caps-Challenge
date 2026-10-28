
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select severity
from "carton_caps"."quality"."dq_issues"
where severity is null



  
  
      
    ) dbt_internal_test