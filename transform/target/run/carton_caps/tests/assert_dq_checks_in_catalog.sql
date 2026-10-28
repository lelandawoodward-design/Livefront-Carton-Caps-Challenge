
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  -- Every check a model can emit must be documented in the check catalog.
select distinct entity, check_name
from "carton_caps"."quality"."dq_issues"
where severity is null
  
  
      
    ) dbt_internal_test