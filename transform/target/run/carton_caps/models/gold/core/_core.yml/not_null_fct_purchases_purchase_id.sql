
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select purchase_id
from "carton_caps"."gold"."fct_purchases"
where purchase_id is null



  
  
      
    ) dbt_internal_test