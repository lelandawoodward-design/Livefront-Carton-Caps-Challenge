
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select school_id
from "carton_caps"."gold"."dim_users"
where school_id is null



  
  
      
    ) dbt_internal_test