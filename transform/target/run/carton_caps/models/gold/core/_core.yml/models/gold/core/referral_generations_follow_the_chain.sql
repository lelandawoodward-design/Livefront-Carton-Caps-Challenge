
    -- Build actual result given inputs
with dbt_internal_unit_test_actual as (
  select
    "user_id","acquisition_channel","referral_generation","root_user_id","is_activated", 'actual' as "actual_or_expected"
  from (
    -- Valid users with how they were acquired and where they sit in the referral network.
with recursive

 __dbt__cte__stg_users as (

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
),  __dbt__cte__int_referrals_checked as (

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
),  __dbt__cte__int_purchases_checked as (

-- Fixture for int_purchases_checked
select cast(null as character varying(256)) as "record_key", cast(null as BIGINT) as "purchase_id", 
    
    cast(3 as INTEGER)
 as "user_id", cast(null as INTEGER) as "product_id", cast(null as INTEGER) as "quantity", cast(null as DECIMAL(12,2)) as "price_paid", cast(null as INTEGER) as "points_reported", cast(null as INTEGER) as "points_expected", 
    
    cast('2024-01-21 10:00:00' as TIMESTAMP)
 as "purchased_at", cast(null as character varying(256)) as "natural_key", cast(null as BIGINT) as "copies", cast(null as DATE) as "first_batch_id", cast(null as DATE) as "last_batch_id", cast(null as VARCHAR[]) as "dq_issues", cast(null as character varying(256)) as "dq_issues_text", 
    
    cast('valid' as character varying)
 as "dq_status", cast(null as DATE) as "evaluated_batch_id"
), users as (
    select * from __dbt__cte__stg_users where dq_status = 'valid'
),

-- The valid invite each referred user joined through (last touch).
referral_links as (
    select
        referred_user_id as user_id,
        referrer_user_id,
        referral_id
    from __dbt__cte__int_referrals_checked
    where dq_status = 'valid' and status = 'converted'
    qualify row_number() over (partition by referred_user_id order by converted_at, referral_id) = 1
),

-- Generation 0 is an organic user; each referral hop adds one.
generations (user_id, generation, root_user_id) as (
    select u.user_id, 0, u.user_id
    from users as u
    where u.user_id not in (select user_id from referral_links)
    union all
    select l.user_id, g.generation + 1, g.root_user_id
    from referral_links as l
    inner join generations as g on g.user_id = l.referrer_user_id
    where g.generation < 50
),

first_purchases as (
    select user_id, min(purchased_at) as first_purchase_at
    from __dbt__cte__int_purchases_checked
    where dq_status = 'valid'
    group by user_id
)

select
    u.user_id,
    u.school_id,
    u.user_type,
    u.signup_at,
    cast(u.signup_at as date)                          as signup_date,
    cast(date_trunc('month', u.signup_at) as date)     as signup_cohort_month,
    case when l.user_id is null then 'organic' else 'referral' end as acquisition_channel,
    l.referrer_user_id,
    l.referral_id                                      as joined_via_referral_id,
    g.generation                                       as referral_generation,
    g.root_user_id                                     as root_user_id,
    f.first_purchase_at,
    f.first_purchase_at is not null                    as is_activated,
    date_diff('day', u.signup_at, f.first_purchase_at) as days_to_first_purchase,
    u.email_hash,
    u.has_shared_email
from users as u
left join referral_links as l on l.user_id = u.user_id
left join generations as g on g.user_id = u.user_id
left join first_purchases as f on f.user_id = u.user_id
  ) _dbt_internal_unit_test_actual
),
-- Build expected result
dbt_internal_unit_test_expected as (
  select
    "user_id", "acquisition_channel", "referral_generation", "root_user_id", "is_activated", 'expected' as "actual_or_expected"
  from (
    select 
    
    cast(1 as INTEGER)
 as "user_id", 
    
    cast('organic' as character varying)
 as "acquisition_channel", 
    
    cast(0 as INTEGER)
 as "referral_generation", 
    
    cast(1 as INTEGER)
 as "root_user_id", 
    
    cast(False as BOOLEAN)
 as "is_activated"
union all
select 
    
    cast(2 as INTEGER)
 as "user_id", 
    
    cast('referral' as character varying)
 as "acquisition_channel", 
    
    cast(1 as INTEGER)
 as "referral_generation", 
    
    cast(1 as INTEGER)
 as "root_user_id", 
    
    cast(False as BOOLEAN)
 as "is_activated"
union all
select 
    
    cast(3 as INTEGER)
 as "user_id", 
    
    cast('referral' as character varying)
 as "acquisition_channel", 
    
    cast(2 as INTEGER)
 as "referral_generation", 
    
    cast(1 as INTEGER)
 as "root_user_id", 
    
    cast(True as BOOLEAN)
 as "is_activated"
union all
select 
    
    cast(4 as INTEGER)
 as "user_id", 
    
    cast('organic' as character varying)
 as "acquisition_channel", 
    
    cast(0 as INTEGER)
 as "referral_generation", 
    
    cast(4 as INTEGER)
 as "root_user_id", 
    
    cast(False as BOOLEAN)
 as "is_activated"
  ) _dbt_internal_unit_test_expected
)
-- Union actual and expected results
select * from dbt_internal_unit_test_actual
union all
select * from dbt_internal_unit_test_expected