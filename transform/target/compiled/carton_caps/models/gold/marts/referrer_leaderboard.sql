-- One row per user who sent at least one valid invite: direct results plus the
-- whole downstream network they started (referrals of referrals, and so on).
with recursive

links as (
    select referrer_user_id as parent_id, referred_user_id as child_id
    from "carton_caps"."gold"."fct_referrals"
    where is_converted
),

descendants (root_id, user_id, depth) as (
    select parent_id, child_id, 1 from links
    union all
    select d.root_id, l.child_id, d.depth + 1
    from descendants as d
    inner join links as l on l.parent_id = d.user_id
    where d.depth < 50
),

network as (
    select root_id as user_id, count(distinct user_id) as network_size, max(depth) as deepest_chain
    from descendants
    group by all
),

network_funds as (
    select d.root_id as user_id, sum(p.dollars_raised) as network_dollars_raised
    from (select distinct root_id, user_id from descendants) as d
    inner join "carton_caps"."gold"."fct_purchases" as p on p.user_id = d.user_id
    group by all
),

direct as (
    select
        referrer_user_id                          as user_id,
        count(*)                                  as invites,
        count(*) filter (where is_clicked)        as clicked,
        count(*) filter (where is_converted)      as direct_referrals,
        count(*) filter (where is_qualified)      as qualified_referrals,
        count(*) filter (where is_converted and is_same_school) as same_school_referrals,
        sum(bonus_usd) / 2                        as bonuses_earned_usd
    from "carton_caps"."gold"."fct_referrals"
    group by all
)

select
    d.user_id,
    u.school_id,
    u.user_type,
    u.acquisition_channel,
    u.referral_generation,
    d.invites,
    d.clicked,
    d.direct_referrals,
    d.qualified_referrals,
    round(d.direct_referrals / d.invites, 4)       as conversion_rate,
    d.same_school_referrals,
    coalesce(n.network_size, 0)                    as network_size,
    coalesce(n.deepest_chain, 0)                   as deepest_chain,
    coalesce(f.network_dollars_raised, 0)          as network_dollars_raised,
    d.bonuses_earned_usd,
    rank() over (order by coalesce(n.network_size, 0) desc, d.direct_referrals desc, d.invites desc) as network_rank
from direct as d
inner join "carton_caps"."gold"."dim_users" as u on u.user_id = d.user_id
left join network as n on n.user_id = d.user_id
left join network_funds as f on f.user_id = d.user_id