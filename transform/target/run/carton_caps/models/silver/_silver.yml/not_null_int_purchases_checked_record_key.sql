
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select record_key
from "carton_caps"."silver"."int_purchases_checked"
where record_key is null



  
  
      
    ) dbt_internal_test