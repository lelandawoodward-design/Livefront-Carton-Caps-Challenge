
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    record_key as unique_field,
    count(*) as n_records

from "carton_caps"."silver"."int_purchases_checked"
where record_key is not null
group by record_key
having count(*) > 1



  
  
      
    ) dbt_internal_test