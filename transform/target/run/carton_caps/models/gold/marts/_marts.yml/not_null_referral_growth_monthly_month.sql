
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select month
from "carton_caps"."gold"."referral_growth_monthly"
where month is null



  
  
      
    ) dbt_internal_test