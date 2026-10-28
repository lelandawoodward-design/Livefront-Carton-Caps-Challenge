
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select * from "carton_caps"."silver"."stg_products" where not coalesce((list_price > 0), false)

  
  
      
    ) dbt_internal_test