
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    select * from "carton_caps"."gold"."referrer_leaderboard" where not coalesce((network_size >= direct_referrals), false)

  
  
      
    ) dbt_internal_test