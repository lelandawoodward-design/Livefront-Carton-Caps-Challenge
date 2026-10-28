
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    referred_user_id as unique_field,
    count(*) as n_records

from "carton_caps"."gold"."fct_referrals"
where referred_user_id is not null
group by referred_user_id
having count(*) > 1



  
  
      
    ) dbt_internal_test