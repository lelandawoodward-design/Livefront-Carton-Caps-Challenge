
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select * from "carton_caps"."gold"."fct_referrals" where not coalesce((not is_qualified or is_converted), false)

  
  
      
    ) dbt_internal_test