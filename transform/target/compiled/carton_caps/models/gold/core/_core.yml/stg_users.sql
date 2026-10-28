
-- Fixture for stg_users
select 
    
    cast(1 as INTEGER)
 as "user_id", 
    
    cast(1 as INTEGER)
 as "school_id", cast(null as character varying(256)) as "user_type", 
    
    cast('2024-01-01 08:00:00' as TIMESTAMP)
 as "signup_at", cast(null as character varying(256)) as "email_hash", cast(null as BOOLEAN) as "has_shared_email", cast(null as VARCHAR[]) as "dq_issues", cast(null as character varying(256)) as "dq_issues_text", 
    
    cast('valid' as character varying)
 as "dq_status", cast(null as DATE) as "first_seen_batch_id", cast(null as DATE) as "snapshot_batch_id"
union all
select 
    
    cast(2 as INTEGER)
 as "user_id", 
    
    cast(1 as INTEGER)
 as "school_id", cast(null as character varying(256)) as "user_type", 
    
    cast('2024-01-10 08:00:00' as TIMESTAMP)
 as "signup_at", cast(null as character varying(256)) as "email_hash", cast(null as BOOLEAN) as "has_shared_email", cast(null as VARCHAR[]) as "dq_issues", cast(null as character varying(256)) as "dq_issues_text", 
    
    cast('valid' as character varying)
 as "dq_status", cast(null as DATE) as "first_seen_batch_id", cast(null as DATE) as "snapshot_batch_id"
union all
select 
    
    cast(3 as INTEGER)
 as "user_id", 
    
    cast(1 as INTEGER)
 as "school_id", cast(null as character varying(256)) as "user_type", 
    
    cast('2024-01-20 08:00:00' as TIMESTAMP)
 as "signup_at", cast(null as character varying(256)) as "email_hash", cast(null as BOOLEAN) as "has_shared_email", cast(null as VARCHAR[]) as "dq_issues", cast(null as character varying(256)) as "dq_issues_text", 
    
    cast('valid' as character varying)
 as "dq_status", cast(null as DATE) as "first_seen_batch_id", cast(null as DATE) as "snapshot_batch_id"
union all
select 
    
    cast(4 as INTEGER)
 as "user_id", 
    
    cast(2 as INTEGER)
 as "school_id", cast(null as character varying(256)) as "user_type", 
    
    cast('2024-01-25 08:00:00' as TIMESTAMP)
 as "signup_at", cast(null as character varying(256)) as "email_hash", cast(null as BOOLEAN) as "has_shared_email", cast(null as VARCHAR[]) as "dq_issues", cast(null as character varying(256)) as "dq_issues_text", 
    
    cast('valid' as character varying)
 as "dq_status", cast(null as DATE) as "first_seen_batch_id", cast(null as DATE) as "snapshot_batch_id"