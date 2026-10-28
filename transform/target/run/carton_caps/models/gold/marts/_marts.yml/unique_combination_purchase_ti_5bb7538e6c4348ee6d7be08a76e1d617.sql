
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select day_of_week_number, hour_of_day, count(*) as n
    from "carton_caps"."gold"."purchase_time_heatmap"
    group by day_of_week_number, hour_of_day
    having count(*) > 1

  
  
      
    ) dbt_internal_test