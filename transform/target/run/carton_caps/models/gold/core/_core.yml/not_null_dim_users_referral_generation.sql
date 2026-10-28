
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select referral_generation
from "carton_caps"."gold"."dim_users"
where referral_generation is null



  
  
      
    ) dbt_internal_test