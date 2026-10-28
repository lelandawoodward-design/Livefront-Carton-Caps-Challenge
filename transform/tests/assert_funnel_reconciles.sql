-- The 'all' rows of the funnel must match the referral fact table.
with funnel as (
    select sum(invites) as invites, sum(converted) as converted, sum(qualified) as qualified,
           sum(bonus_cost_usd) as bonus
    from {{ ref('referral_funnel_monthly') }}
    where referrer_segment = 'all'
),

facts as (
    select count(*) as invites,
           count(*) filter (where is_converted) as converted,
           count(*) filter (where is_qualified) as qualified,
           sum(bonus_usd) as bonus
    from {{ ref('fct_referrals') }}
)

select f.*, x.*
from funnel as f, facts as x
where f.invites <> x.invites or f.converted <> x.converted
   or f.qualified <> x.qualified or f.bonus <> x.bonus
