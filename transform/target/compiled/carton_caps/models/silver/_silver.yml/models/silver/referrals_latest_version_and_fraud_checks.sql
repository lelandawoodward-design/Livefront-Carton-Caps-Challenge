

-- One row per referral invite in its latest state, with its data-quality verdict.
--
-- Referrals change after they are sent (sent -> clicked -> converted), so the
-- feed re-sends a row whenever its state changes and the latest batch wins.
-- Incremental runs re-evaluate: invites with a new version, invites currently
-- quarantined, and existing invites from the same referrer to the same address
-- (for the duplicate-send check). Every version of a re-evaluated invite is
-- read again, so the result equals a full rebuild.

with



 __dbt__cte__stg_referrals as (

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
),  __dbt__cte__stg_users as (

-- Fixture for stg_users
select 
    
    cast(10 as INTEGER)
 as "user_id", cast(null as INTEGER) as "school_id", cast(null as character varying(256)) as "user_type", 
    
    cast('2023-08-01 08:00:00' as TIMESTAMP)
 as "signup_at", 
    
    cast('h_10' as character varying)
 as "email_hash", cast(null as BOOLEAN) as "has_shared_email", cast(null as VARCHAR[]) as "dq_issues", cast(null as character varying(256)) as "dq_issues_text", 
    
    cast('valid' as character varying)
 as "dq_status", cast(null as DATE) as "first_seen_batch_id", cast(null as DATE) as "snapshot_batch_id"
union all
select 
    
    cast(20 as INTEGER)
 as "user_id", cast(null as INTEGER) as "school_id", cast(null as character varying(256)) as "user_type", 
    
    cast('2023-09-01 08:00:00' as TIMESTAMP)
 as "signup_at", 
    
    cast('h_20' as character varying)
 as "email_hash", cast(null as BOOLEAN) as "has_shared_email", cast(null as VARCHAR[]) as "dq_issues", cast(null as character varying(256)) as "dq_issues_text", 
    
    cast('valid' as character varying)
 as "dq_status", cast(null as DATE) as "first_seen_batch_id", cast(null as DATE) as "snapshot_batch_id"
union all
select 
    
    cast(30 as INTEGER)
 as "user_id", cast(null as INTEGER) as "school_id", cast(null as character varying(256)) as "user_type", 
    
    cast('2024-02-01 09:00:00' as TIMESTAMP)
 as "signup_at", 
    
    cast('h_new' as character varying)
 as "email_hash", cast(null as BOOLEAN) as "has_shared_email", cast(null as VARCHAR[]) as "dq_issues", cast(null as character varying(256)) as "dq_issues_text", 
    
    cast('valid' as character varying)
 as "dq_status", cast(null as DATE) as "first_seen_batch_id", cast(null as DATE) as "snapshot_batch_id"
),  __dbt__cte__dq_check_catalog as (

-- Fixture for dq_check_catalog
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('unparseable_or_missing' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('A key, timestamp, quantity or amount is missing or cannot be parsed' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('conflicting_duplicate' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The same purchase_id arrived with different content' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('exact_duplicate' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('drop_extra_copies' as character varying)
 as "action", 
    
    cast('The same purchase_id arrived more than once with identical content (replayed upload); one copy is kept' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('retry_duplicate' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Same user, product, timestamp, quantity and amount as an earlier purchase_id (client retry)' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('orphan_product' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('product_id is not in the product catalog' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('orphan_user' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('user_id is not in users (re-checked every run in case the user arrives later)' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('user_quarantined' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The purchasing user is quarantined' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('non_positive_quantity' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Quantity is zero or negative' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('price_out_of_range' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('price_paid is not positive, exceeds the list amount, or is below min_price_ratio of it' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('before_signup' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Purchased before the user signed up' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('future_timestamp' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Purchased after the cutoff of the batch it arrived in' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('points_mismatch' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('repair' as character varying)
 as "action", 
    
    cast('points_earned differs from floor(price_paid x points_per_dollar); the rule value is used' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('derived_field_mismatch' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('repair' as character varying)
 as "action", 
    
    cast('day_of_week or hour_of_day disagree with purchased_at; recomputed from the timestamp' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('unparseable_or_missing' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('referral_id, referrer, sent_at or status is missing or cannot be parsed' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('conflicting_duplicate' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The same referral_id arrived twice in one batch with different content' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('invalid_status' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('status is not sent, clicked or converted' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('orphan_referrer' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The referrer is not a valid user' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('unknown_referred_user' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('referred_user_id is not in users' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('self_referral' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The invited email is the referrer''s own (after normalising case and +tags)' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('status_inconsistent' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Status converted without a referred user and converted_at (or the reverse)' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('existing_member' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Converted to someone who was already a member when the invite was sent' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('converted_before_sent' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('converted_at is earlier than sent_at' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('duplicate_send' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Same referrer invited the same email within duplicate_send_window_hours; the later invite is quarantined' as character varying)
 as "description"
union all
select 
    
    cast('users' as character varying)
 as "entity", 
    
    cast('unparseable_or_missing' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('user_id or created_at is missing or cannot be parsed' as character varying)
 as "description"
union all
select 
    
    cast('users' as character varying)
 as "entity", 
    
    cast('orphan_school' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('school_id is not in schools' as character varying)
 as "description"
union all
select 
    
    cast('users' as character varying)
 as "entity", 
    
    cast('invalid_user_type' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('user_type is not parent, teacher or supporter' as character varying)
 as "description"
union all
select 
    
    cast('users' as character varying)
 as "entity", 
    
    cast('shared_email' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('flag' as character varying)
 as "action", 
    
    cast('Another user has the same email; joins never use email' as character varying)
 as "description"
),  __dbt__cte__meta__ingested_files as (

-- Fixture for ingested_files
select cast(null as character varying(256)) as "file_path", 
    
    cast('2024-02-29' as DATE)
 as "batch_id", cast(null as character varying(256)) as "entity", cast(null as character varying(256)) as "sha256", cast(null as BIGINT) as "row_count", cast(null as TIMESTAMP) as "ingested_at"
), versions as (
    select *
    from __dbt__cte__stg_referrals
    
),

version_stats as (
    select
        record_key,
        count(*)       as versions,
        min(_batch_id) as first_batch_id,
        max(_batch_id) as last_batch_id
    from versions
    group by record_key
),

latest_versions as (
    select *
    from versions
    qualify _batch_id = max(_batch_id) over (partition by record_key)
),

conflicts as (
    select record_key, count(distinct content_hash) > 1 as has_conflict
    from latest_versions
    group by record_key
),

candidates as (
    select lv.*, s.versions, s.first_batch_id, s.last_batch_id, c.has_conflict
    from latest_versions as lv
    inner join version_stats as s on s.record_key = lv.record_key
    inner join conflicts as c on c.record_key = lv.record_key
    qualify row_number() over (partition by lv.record_key order by lv._row_number desc) = 1
),

-- Invites from the same referrer to the same address, including untouched existing ones.
send_peers as (
    select record_key, referral_id, referrer_user_id, referred_email_hash, sent_at
    from candidates
    
),

-- An invite repeated within the window: the later one is the duplicate.
duplicate_sends as (
    select distinct c.record_key
    from candidates as c
    inner join send_peers as p
        on p.referrer_user_id = c.referrer_user_id
       and p.referred_email_hash = c.referred_email_hash
       and p.record_key <> c.record_key
       and (p.sent_at < c.sent_at or (p.sent_at = c.sent_at and p.referral_id < c.referral_id))
       and c.sent_at <= p.sent_at + to_hours(24)
),

checked as (
    select
        c.record_key,
        c.referral_id,
        c.referrer_user_id,
        c.referred_email_hash,
        c.referred_user_id,
        c.referral_code,
        c.sent_at,
        c.converted_at,
        c.status,
        c.versions,
        c.first_batch_id,
        c.last_batch_id,
        list_filter([
            case when c.referral_id is null or c.referrer_user_id is null
                      or c.sent_at is null or c.status is null
                 then 'unparseable_or_missing' end,
            case when c.has_conflict then 'conflicting_duplicate' end,
            case when c.status not in ('sent', 'clicked', 'converted') then 'invalid_status' end,
            case when c.referrer_user_id is not null
                      and (referrer.user_id is null or referrer.dq_status = 'quarantined')
                 then 'orphan_referrer' end,
            case when c.referred_user_id is not null and referred.user_id is null
                 then 'unknown_referred_user' end,
            case when c.referred_email_hash = referrer.email_hash then 'self_referral' end,
            case when coalesce((c.status = 'converted') <> (c.referred_user_id is not null and c.converted_at is not null), false)
                      or (c.status <> 'converted' and (c.referred_user_id is not null or c.converted_at is not null))
                 then 'status_inconsistent' end,
            case when c.status = 'converted' and referred.signup_at < c.sent_at and c.converted_at >= c.sent_at
                 then 'existing_member' end,
            case when c.converted_at < c.sent_at then 'converted_before_sent' end,
            case when d.record_key is not null then 'duplicate_send' end
        ], lambda x: x is not null) as dq_issues
    from candidates as c
    left join __dbt__cte__stg_users as referrer on referrer.user_id = c.referrer_user_id
    left join __dbt__cte__stg_users as referred on referred.user_id = c.referred_user_id
    left join duplicate_sends as d on d.record_key = c.record_key
)

select
    *,
    array_to_string(dq_issues, ', ')          as dq_issues_text,
    case
        when list_has_any(dq_issues, (
            select list(check_name) from __dbt__cte__dq_check_catalog
            where entity = 'referrals' and action = 'quarantine'
        )) then 'quarantined'
        else 'valid'
    end as dq_status,
    (select max(batch_id) from __dbt__cte__meta__ingested_files)                   as evaluated_batch_id  -- the run that last (re)checked this record
from checked