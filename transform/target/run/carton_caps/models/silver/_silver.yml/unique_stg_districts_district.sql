
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    district as unique_field,
    count(*) as n_records

from "carton_caps"."silver"."stg_districts"
where district is not null
group by district
having count(*) > 1



  
  
      
    ) dbt_internal_test