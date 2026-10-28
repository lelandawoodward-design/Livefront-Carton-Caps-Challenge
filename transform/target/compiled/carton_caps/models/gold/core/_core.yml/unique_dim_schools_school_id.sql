
    
    

select
    school_id as unique_field,
    count(*) as n_records

from "carton_caps"."gold"."dim_schools"
where school_id is not null
group by school_id
having count(*) > 1


