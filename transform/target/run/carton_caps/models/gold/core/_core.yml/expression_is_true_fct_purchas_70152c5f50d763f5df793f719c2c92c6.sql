
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select * from "carton_caps"."gold"."fct_purchases" where not coalesce((price_paid > 0 and price_paid <= list_amount), false)

  
  
      
    ) dbt_internal_test