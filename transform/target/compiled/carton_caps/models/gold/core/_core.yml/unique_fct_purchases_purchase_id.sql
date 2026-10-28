
    
    

select
    purchase_id as unique_field,
    count(*) as n_records

from "carton_caps"."gold"."fct_purchases"
where purchase_id is not null
group by purchase_id
having count(*) > 1


