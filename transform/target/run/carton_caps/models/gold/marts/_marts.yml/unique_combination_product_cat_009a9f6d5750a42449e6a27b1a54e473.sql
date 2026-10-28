
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select month, category, user_type, count(*) as n
    from "carton_caps"."gold"."product_category_monthly"
    group by month, category, user_type
    having count(*) > 1

  
  
      
    ) dbt_internal_test