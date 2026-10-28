
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        points_per_dollar as value_field,
        count(*) as n_records

    from "carton_caps"."silver"."stg_products"
    group by points_per_dollar

)

select *
from all_values
where value_field not in (
    1,2,3,5
)



  
  
      
    ) dbt_internal_test