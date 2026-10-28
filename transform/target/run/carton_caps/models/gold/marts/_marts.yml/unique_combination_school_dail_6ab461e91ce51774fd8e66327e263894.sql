
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select activity_date, school_id, count(*) as n
    from "carton_caps"."gold"."school_daily_activity"
    group by activity_date, school_id
    having count(*) > 1

  
  
      
    ) dbt_internal_test