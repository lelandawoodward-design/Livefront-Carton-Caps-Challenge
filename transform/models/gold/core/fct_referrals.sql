-- One row per valid referral invite, with its funnel stage.
with referrals as (
    select * from {{ ref('referrals_checked') }} where dq_status = 'valid'
),

data_end as (
    select max(date_day) + interval 1 day as ends_at from {{ ref('dim_date') }}
),

first_purchases as (
    select user_id, min(purchased_at) as first_purchase_at
    from {{ ref('fct_purchases') }}
    group by user_id
),

invites_per_referrer as (
    select referrer_user_id, count(*) as invites
    from referrals
    group by referrer_user_id
),

-- People who joined through a referral, to mark earlier invites to them as assists.
referral_joiners as (
    select email_hash, joined_via_referral_id, signup_at
    from {{ ref('dim_users') }}
    where acquisition_channel = 'referral' and email_hash is not null
),

staged as (
    select
        r.referral_id,
        r.referrer_user_id,
        referrer.school_id                                        as referrer_school_id,
        referrer.user_type                                        as referrer_user_type,
        case when i.invites <= 2 then '1-2 invites'
             when i.invites <= 9 then '3-9 invites'
             else '10+ invites' end                               as referrer_segment,
        r.referred_user_id,
        referred.school_id                                        as referred_school_id,
        r.referred_email_hash,
        r.referral_code,
        r.sent_at,
        cast(date_trunc('month', r.sent_at) as date)              as sent_month,
        r.converted_at,
        r.status,
        r.status in ('clicked', 'converted')                      as is_clicked,
        r.status = 'converted'                                    as is_converted,
        r.status = 'converted'
            and fp.first_purchase_at <= r.converted_at + to_days({{ var('qualification_window_days') }})
                                                                  as is_qualified,
        -- Converted too recently to know yet whether they will qualify (right-censored).
        r.status = 'converted'
            and r.converted_at + to_days({{ var('qualification_window_days') }})
                <= (select ends_at from data_end)                 as is_qualification_window_complete,
        fp.first_purchase_at                                      as referred_first_purchase_at,
        round(date_diff('second', r.sent_at, r.converted_at) / 3600.0, 2) as hours_to_convert,
        referred.school_id = referrer.school_id                   as is_same_school,
        r.status <> 'converted' and exists (
            select 1 from referral_joiners as j
            where j.email_hash = r.referred_email_hash
              and j.joined_via_referral_id <> r.referral_id
              and r.sent_at < j.signup_at
        )                                                         as is_assist
    from referrals as r
    inner join {{ ref('dim_users') }} as referrer on referrer.user_id = r.referrer_user_id
    left join {{ ref('dim_users') }} as referred on referred.user_id = r.referred_user_id
    left join first_purchases as fp on fp.user_id = r.referred_user_id
    left join invites_per_referrer as i on i.referrer_user_id = r.referrer_user_id
)

select
    * exclude (referred_first_purchase_at),
    case when is_qualified then referred_first_purchase_at end      as qualified_at,
    case when is_qualified then 2 * {{ var('referral_bonus_usd') }} else 0 end as bonus_usd
from staged
