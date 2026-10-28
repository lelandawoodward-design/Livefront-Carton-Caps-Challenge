
    
    

with all_values as (

    select
        dq_status as value_field,
        count(*) as n_records

    from "carton_caps"."silver"."stg_users"
    group by dq_status

)

select *
from all_values
where value_field not in (
    'valid','quarantined'
)


