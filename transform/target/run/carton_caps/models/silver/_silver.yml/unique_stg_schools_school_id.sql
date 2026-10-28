
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    school_id as unique_field,
    count(*) as n_records

from "carton_caps"."silver"."stg_schools"
where school_id is not null
group by school_id
having count(*) > 1



  
  
      
    ) dbt_internal_test