
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select * from "carton_caps"."gold"."dim_users" where not coalesce(((referral_generation = 0) = (acquisition_channel = 'organic')), false)

  
  
      
    ) dbt_internal_test