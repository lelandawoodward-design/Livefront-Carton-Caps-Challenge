
    
    

select
    month as unique_field,
    count(*) as n_records

from "carton_caps"."gold"."referral_growth_monthly"
where month is not null
group by month
having count(*) > 1


