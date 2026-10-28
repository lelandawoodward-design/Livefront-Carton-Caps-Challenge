
    
    

select
    district as unique_field,
    count(*) as n_records

from "carton_caps"."silver"."stg_districts"
where district is not null
group by district
having count(*) > 1


