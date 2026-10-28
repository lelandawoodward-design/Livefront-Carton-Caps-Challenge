
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select income_level, user_type, count(*) as n
    from "carton_caps"."gold"."spending_by_segment"
    group by income_level, user_type
    having count(*) > 1

  
  
      
    ) dbt_internal_test