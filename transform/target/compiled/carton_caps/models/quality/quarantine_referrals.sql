

-- Referral invites held back from gold, with why. Re-checked on every run.
select
    record_key,
    referral_id,
    referrer_user_id,
    referred_user_id,
    referral_code,
    sent_at,
    converted_at,
    status,
    dq_issues_text as issues,
    first_batch_id,
    last_batch_id,
    evaluated_batch_id
from "carton_caps"."silver"."int_referrals_checked"
where dq_status = 'quarantined'