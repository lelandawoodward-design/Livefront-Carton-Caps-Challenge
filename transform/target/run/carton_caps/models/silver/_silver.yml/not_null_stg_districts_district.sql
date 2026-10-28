
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select district
from "carton_caps"."silver"."stg_districts"
where district is null



  
  
      
    ) dbt_internal_test