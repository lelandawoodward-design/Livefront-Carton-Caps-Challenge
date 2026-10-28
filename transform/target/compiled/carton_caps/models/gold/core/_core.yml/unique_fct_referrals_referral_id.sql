
    
    

select
    referral_id as unique_field,
    count(*) as n_records

from "carton_caps"."gold"."fct_referrals"
where referral_id is not null
group by referral_id
having count(*) > 1


