
    
    

select
    referred_user_id as unique_field,
    count(*) as n_records

from "carton_caps"."gold"."fct_referrals"
where referred_user_id is not null
group by referred_user_id
having count(*) > 1


