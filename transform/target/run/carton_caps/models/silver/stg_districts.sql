
    

    create  table
      "carton_caps"."silver"."stg_districts__dbt_tmp"
  
    
    as (
      -- School districts with income level (reference data), from the latest snapshot.
with latest as (
    select *
    from "carton_caps"."bronze"."districts"
    where _batch_id = (select max(_batch_id) from "carton_caps"."bronze"."districts")
)

select
    nullif(trim(district), '')                      as district,
    nullif(trim(city), '')                          as city,
    nullif(trim(state), '')                         as state,
    lower(trim(income_level))                       as income_level,
    try_cast(median_household_income as integer)    as median_household_income,
    _batch_id                                       as snapshot_batch_id
from latest
    );
    
  