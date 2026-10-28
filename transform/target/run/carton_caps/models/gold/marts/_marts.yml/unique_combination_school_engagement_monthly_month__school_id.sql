
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select month, school_id, count(*) as n
    from "carton_caps"."gold"."school_engagement_monthly"
    group by month, school_id
    having count(*) > 1

  
  
      
    ) dbt_internal_test