-- Monthly growth from referrals: signups, referral share, invites per active user,
-- and the viral coefficient K = invites per active user x invite conversion rate.
with months as (
    select distinct month_start as month from {{ ref('dim_date') }}
),

active as (
    select activity_month as month, count(distinct user_id) as active_users
    from {{ ref('fct_user_activity_daily') }}
    group by all
),

signups as (
    select
        signup_cohort_month                                    as month,
        count(*)                                               as signups,
        count(*) filter (where acquisition_channel = 'referral') as referral_signups
    from {{ ref('dim_users') }}
    group by all
),

invites as (
    select
        sent_month                              as month,
        count(*)                                as invites,
        count(*) filter (where is_converted)    as converted_invites
    from {{ ref('fct_referrals') }}
    group by all
)

select
    m.month,
    coalesce(a.active_users, 0)                                              as active_users,
    coalesce(s.signups, 0)                                                   as signups,
    coalesce(s.referral_signups, 0)                                          as referral_signups,
    round(coalesce(s.referral_signups, 0) / nullif(s.signups, 0), 4)         as referral_share_of_signups,
    coalesce(i.invites, 0)                                                   as invites,
    round(coalesce(i.invites, 0) / nullif(a.active_users, 0), 4)             as invites_per_active_user,
    round(i.converted_invites / nullif(i.invites, 0), 4)                     as invite_conversion_rate,
    round(coalesce(i.converted_invites, 0) / nullif(a.active_users, 0), 4)   as k_factor
from months as m
left join active as a on a.month = m.month
left join signups as s on s.month = m.month
left join invites as i on i.month = m.month
