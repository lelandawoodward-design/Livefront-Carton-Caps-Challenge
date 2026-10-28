
-- Fixture for int_referrals_checked
select cast(null as character varying(256)) as "record_key", 
    
    cast(11 as BIGINT)
 as "referral_id", 
    
    cast(1 as INTEGER)
 as "referrer_user_id", cast(null as character varying(256)) as "referred_email_hash", 
    
    cast(2 as INTEGER)
 as "referred_user_id", cast(null as character varying(256)) as "referral_code", cast(null as TIMESTAMP) as "sent_at", 
    
    cast('2024-01-10 08:00:00' as TIMESTAMP)
 as "converted_at", 
    
    cast('converted' as character varying)
 as "status", cast(null as BIGINT) as "versions", cast(null as DATE) as "first_batch_id", cast(null as DATE) as "last_batch_id", cast(null as VARCHAR[]) as "dq_issues", cast(null as character varying(256)) as "dq_issues_text", 
    
    cast('valid' as character varying)
 as "dq_status", cast(null as DATE) as "evaluated_batch_id"
union all
select cast(null as character varying(256)) as "record_key", 
    
    cast(12 as BIGINT)
 as "referral_id", 
    
    cast(2 as INTEGER)
 as "referrer_user_id", cast(null as character varying(256)) as "referred_email_hash", 
    
    cast(3 as INTEGER)
 as "referred_user_id", cast(null as character varying(256)) as "referral_code", cast(null as TIMESTAMP) as "sent_at", 
    
    cast('2024-01-20 08:00:00' as TIMESTAMP)
 as "converted_at", 
    
    cast('converted' as character varying)
 as "status", cast(null as BIGINT) as "versions", cast(null as DATE) as "first_batch_id", cast(null as DATE) as "last_batch_id", cast(null as VARCHAR[]) as "dq_issues", cast(null as character varying(256)) as "dq_issues_text", 
    
    cast('valid' as character varying)
 as "dq_status", cast(null as DATE) as "evaluated_batch_id"
union all
select cast(null as character varying(256)) as "record_key", 
    
    cast(13 as BIGINT)
 as "referral_id", 
    
    cast(2 as INTEGER)
 as "referrer_user_id", cast(null as character varying(256)) as "referred_email_hash", 
    
    cast(4 as INTEGER)
 as "referred_user_id", cast(null as character varying(256)) as "referral_code", cast(null as TIMESTAMP) as "sent_at", 
    
    cast('2024-01-25 08:00:00' as TIMESTAMP)
 as "converted_at", 
    
    cast('converted' as character varying)
 as "status", cast(null as BIGINT) as "versions", cast(null as DATE) as "first_batch_id", cast(null as DATE) as "last_batch_id", cast(null as VARCHAR[]) as "dq_issues", cast(null as character varying(256)) as "dq_issues_text", 
    
    cast('quarantined' as character varying)
 as "dq_status", cast(null as DATE) as "evaluated_batch_id"