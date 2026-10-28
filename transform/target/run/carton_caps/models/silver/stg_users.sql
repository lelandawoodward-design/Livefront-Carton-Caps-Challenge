
    

    create  table
      "carton_caps"."silver"."stg_users__dbt_tmp"
  
    
    as (
      -- Current users from the latest snapshot, typed and validated.
-- Names and raw emails stay in bronze; silver keeps only a keyed email hash.
with latest as (
    select *
    from "carton_caps"."bronze"."users"
    where _batch_id = (select max(_batch_id) from "carton_caps"."bronze"."users")
),

first_seen as (
    select user_id, min(_batch_id) as first_seen_batch_id
    from "carton_caps"."bronze"."users"
    group by user_id
),

typed as (
    select
        try_cast(l.user_id as integer)      as user_id,
        try_cast(l.school_id as integer)    as school_id,
        lower(trim(l.user_type))            as user_type,
        try_cast(l.created_at as timestamp) as signup_at,
        case when nullif(trim(l.email), '') is not null then
        sha256('local-dev-salt' || regexp_replace(lower(trim(l.email)), '\+[^@]*@', '@'))
    end         as email_hash,
        f.first_seen_batch_id,
        l._batch_id                         as snapshot_batch_id
    from latest as l
    left join first_seen as f on f.user_id = l.user_id
),

with_counts as (
    select
        *,
        case when email_hash is not null
             then count(*) over (partition by email_hash) end as users_with_email
    from typed
),

checked as (
    select
        u.*,
        coalesce(u.users_with_email, 1) > 1 as has_shared_email,
        list_filter([
            case when u.user_id is null or u.signup_at is null then 'unparseable_or_missing' end,
            case when s.school_id is null then 'orphan_school' end,
            case when u.user_type is null or u.user_type not in ('parent', 'teacher', 'supporter')
                 then 'invalid_user_type' end,
            case when coalesce(u.users_with_email, 1) > 1 then 'shared_email' end
        ], lambda x: x is not null) as dq_issues
    from with_counts as u
    left join "carton_caps"."silver"."stg_schools" as s on s.school_id = u.school_id
)

select
    user_id,
    school_id,
    user_type,
    signup_at,
    email_hash,
    has_shared_email,
    dq_issues,
    array_to_string(dq_issues, ', ')      as dq_issues_text,
    case
        when list_has_any(dq_issues, (
            select list(check_name) from "carton_caps"."quality"."dq_check_catalog"
            where entity = 'users' and action = 'quarantine'
        )) then 'quarantined'
        else 'valid'
    end as dq_status,
    first_seen_batch_id,
    snapshot_batch_id
from checked
    );
    
  