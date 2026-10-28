
    

    create  table
      "carton_caps"."silver"."stg_schools__dbt_tmp"
  
    
    as (
      -- Current schools: the latest snapshot, typed. A school missing from the latest snapshot no longer exists.
with latest as (
    select *
    from "carton_caps"."bronze"."schools"
    where _batch_id = (select max(_batch_id) from "carton_caps"."bronze"."schools")
)

select
    try_cast(school_id as integer)    as school_id,
    nullif(trim(name), '')            as school_name,
    address,
    city,
    state,
    zip_code,
    try_cast(created_at as timestamp) as created_at,
    _batch_id                         as snapshot_batch_id
from latest
    );
    
  