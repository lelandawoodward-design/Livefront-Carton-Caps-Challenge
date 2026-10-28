
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select * from "carton_caps"."gold"."referral_funnel_monthly" where not coalesce((invites >= clicked and clicked >= converted and converted >= qualified), false)

  
  
      
    ) dbt_internal_test