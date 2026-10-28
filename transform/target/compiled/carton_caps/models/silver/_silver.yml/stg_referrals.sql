
-- Fixture for stg_referrals
select 
    
    cast('1' as character varying)
 as "record_key", 
    
    cast(1 as BIGINT)
 as "referral_id", 
    
    cast(10 as INTEGER)
 as "referrer_user_id", 
    
    cast('h_new' as character varying)
 as "referred_email_hash", cast(null as INTEGER) as "referred_user_id", cast(null as character varying(256)) as "referral_code", 
    
    cast('2024-01-30 20:00:00' as TIMESTAMP)
 as "sent_at", cast(null as TIMESTAMP) as "converted_at", 
    
    cast('clicked' as character varying)
 as "status", 
    
    cast('a1' as character varying)
 as "content_hash", 
    
    cast('2024-01-31' as DATE)
 as "_batch_id", 
    
    cast(1 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file"
union all
select 
    
    cast('1' as character varying)
 as "record_key", 
    
    cast(1 as BIGINT)
 as "referral_id", 
    
    cast(10 as INTEGER)
 as "referrer_user_id", 
    
    cast('h_new' as character varying)
 as "referred_email_hash", 
    
    cast(30 as INTEGER)
 as "referred_user_id", cast(null as character varying(256)) as "referral_code", 
    
    cast('2024-01-30 20:00:00' as TIMESTAMP)
 as "sent_at", 
    
    cast('2024-02-01 09:00:00' as TIMESTAMP)
 as "converted_at", 
    
    cast('converted' as character varying)
 as "status", 
    
    cast('a2' as character varying)
 as "content_hash", 
    
    cast('2024-02-29' as DATE)
 as "_batch_id", 
    
    cast(1 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file"
union all
select 
    
    cast('2' as character varying)
 as "record_key", 
    
    cast(2 as BIGINT)
 as "referral_id", 
    
    cast(10 as INTEGER)
 as "referrer_user_id", 
    
    cast('h_10' as character varying)
 as "referred_email_hash", cast(null as INTEGER) as "referred_user_id", cast(null as character varying(256)) as "referral_code", 
    
    cast('2024-02-03 10:00:00' as TIMESTAMP)
 as "sent_at", cast(null as TIMESTAMP) as "converted_at", 
    
    cast('sent' as character varying)
 as "status", 
    
    cast('b' as character varying)
 as "content_hash", 
    
    cast('2024-02-29' as DATE)
 as "_batch_id", 
    
    cast(2 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file"
union all
select 
    
    cast('3' as character varying)
 as "record_key", 
    
    cast(3 as BIGINT)
 as "referral_id", 
    
    cast(10 as INTEGER)
 as "referrer_user_id", 
    
    cast('h_friend' as character varying)
 as "referred_email_hash", cast(null as INTEGER) as "referred_user_id", cast(null as character varying(256)) as "referral_code", 
    
    cast('2024-02-05 10:00:00' as TIMESTAMP)
 as "sent_at", cast(null as TIMESTAMP) as "converted_at", 
    
    cast('clicked' as character varying)
 as "status", 
    
    cast('c' as character varying)
 as "content_hash", 
    
    cast('2024-02-29' as DATE)
 as "_batch_id", 
    
    cast(3 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file"
union all
select 
    
    cast('4' as character varying)
 as "record_key", 
    
    cast(4 as BIGINT)
 as "referral_id", 
    
    cast(10 as INTEGER)
 as "referrer_user_id", 
    
    cast('h_friend' as character varying)
 as "referred_email_hash", cast(null as INTEGER) as "referred_user_id", cast(null as character varying(256)) as "referral_code", 
    
    cast('2024-02-05 10:05:00' as TIMESTAMP)
 as "sent_at", cast(null as TIMESTAMP) as "converted_at", 
    
    cast('sent' as character varying)
 as "status", 
    
    cast('d' as character varying)
 as "content_hash", 
    
    cast('2024-02-29' as DATE)
 as "_batch_id", 
    
    cast(4 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file"
union all
select 
    
    cast('5' as character varying)
 as "record_key", 
    
    cast(5 as BIGINT)
 as "referral_id", 
    
    cast(10 as INTEGER)
 as "referrer_user_id", 
    
    cast('h_20' as character varying)
 as "referred_email_hash", 
    
    cast(20 as INTEGER)
 as "referred_user_id", cast(null as character varying(256)) as "referral_code", 
    
    cast('2024-02-10 10:00:00' as TIMESTAMP)
 as "sent_at", 
    
    cast('2024-02-10 12:00:00' as TIMESTAMP)
 as "converted_at", 
    
    cast('converted' as character varying)
 as "status", 
    
    cast('e' as character varying)
 as "content_hash", 
    
    cast('2024-02-29' as DATE)
 as "_batch_id", 
    
    cast(5 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file"