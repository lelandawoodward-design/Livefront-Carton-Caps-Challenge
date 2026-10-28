
    

    create  table
      "carton_caps"."silver"."int_referrals_checked"
  
    
    as (
      

-- One row per referral invite in its latest state, with its data-quality verdict.
--
-- Referrals change after they are sent (sent -> clicked -> converted), so the
-- feed re-sends a row whenever its state changes and the latest batch wins.
-- Incremental runs re-evaluate: invites with a new version, invites currently
-- quarantined, and existing invites from the same referrer to the same address
-- (for the duplicate-send check). Every version of a re-evaluated invite is
-- read again, so the result equals a full rebuild.

with



versions as (
    select *
    from "carton_caps"."silver"."stg_referrals"
    
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
    left join "carton_caps"."silver"."stg_users" as referrer on referrer.user_id = c.referrer_user_id
    left join "carton_caps"."silver"."stg_users" as referred on referred.user_id = c.referred_user_id
    left join duplicate_sends as d on d.record_key = c.record_key
)

select
    *,
    array_to_string(dq_issues, ', ')          as dq_issues_text,
    case
        when list_has_any(dq_issues, (
            select list(check_name) from "carton_caps"."quality"."dq_check_catalog"
            where entity = 'referrals' and action = 'quarantine'
        )) then 'quarantined'
        else 'valid'
    end as dq_status,
    (select max(batch_id) from "carton_caps"."meta"."ingested_files")                   as evaluated_batch_id  -- the run that last (re)checked this record
from checked
    );
    
  
  