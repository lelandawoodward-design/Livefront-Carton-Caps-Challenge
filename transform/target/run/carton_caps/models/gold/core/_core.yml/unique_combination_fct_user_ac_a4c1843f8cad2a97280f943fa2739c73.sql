
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select user_id, activity_date, count(*) as n
    from "carton_caps"."gold"."fct_user_activity_daily"
    group by user_id, activity_date
    having count(*) > 1

  
  
      
    ) dbt_internal_test