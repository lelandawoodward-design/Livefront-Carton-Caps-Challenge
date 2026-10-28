
    
    

select
    record_key as unique_field,
    count(*) as n_records

from "carton_caps"."silver"."int_purchases_checked"
where record_key is not null
group by record_key
having count(*) > 1


