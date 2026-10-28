
    
    

with all_values as (

    select
        action as value_field,
        count(*) as n_records

    from "carton_caps"."quality"."dq_check_catalog"
    group by action

)

select *
from all_values
where value_field not in (
    'quarantine','repair','flag','drop_extra_copies'
)


