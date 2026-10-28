
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select * from "carton_caps"."gold"."fct_purchases" where not coalesce((quantity > 0), false)

  
  
      
    ) dbt_internal_test