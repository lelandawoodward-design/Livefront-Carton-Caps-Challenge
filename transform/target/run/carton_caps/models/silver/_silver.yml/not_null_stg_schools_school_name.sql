
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select school_name
from "carton_caps"."silver"."stg_schools"
where school_name is null



  
  
      
    ) dbt_internal_test