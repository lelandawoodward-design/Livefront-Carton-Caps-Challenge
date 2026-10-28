
    
    

with all_values as (

    select
        income_level as value_field,
        count(*) as n_records

    from "carton_caps"."silver"."stg_districts"
    group by income_level

)

select *
from all_values
where value_field not in (
    'low','middle','high'
)


