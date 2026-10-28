
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        dq_status as value_field,
        count(*) as n_records

    from "carton_caps"."silver"."int_purchases_checked"
    group by dq_status

)

select *
from all_values
where value_field not in (
    'valid','quarantined'
)



  
  
      
    ) dbt_internal_test