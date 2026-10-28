
-- depends_on: "carton_caps"."silver"."int_purchases_checked"
-- depends_on: "carton_caps"."silver"."int_referrals_checked"
-- depends_on: "carton_caps"."silver"."stg_users"
-- depends_on: "carton_caps"."meta"."ingested_files"

-- One row per school per day (zero-filled), including DAU and funds raised.
--
-- Incremental runs rebuild only the dates touched by the run: dates of purchase
-- or referral records re-evaluated in this run, and signup dates of users first
-- seen in the newest batch. Every school is written for each rebuilt date, so a
-- date whose activity drops to zero is overwritten rather than left stale.

with



dates as (
    select date_day
    from "carton_caps"."gold"."dim_date"
    
),

activity as (
    select
        school_id,
        activity_date,
        count(*)                                  as active_users,
        count(*) filter (where purchases > 0)     as purchasing_users,
        sum(purchases)                            as purchases,
        sum(spend)                                as spend,
        sum(points_earned)                        as points_earned,
        sum(dollars_raised)                       as dollars_raised,
        sum(referrals_sent)                       as referrals_sent
    from "carton_caps"."gold"."fct_user_activity_daily"
    where activity_date in (select date_day from dates)
    group by all
),

signups as (
    select school_id, signup_date, count(*) as new_users
    from "carton_caps"."gold"."dim_users"
    where signup_date in (select date_day from dates)
    group by all
)

select
    d.date_day                           as activity_date,
    s.school_id,
    s.school_name,
    coalesce(a.active_users, 0)          as active_users,
    coalesce(a.purchasing_users, 0)      as purchasing_users,
    coalesce(n.new_users, 0)             as new_users,
    coalesce(a.purchases, 0)             as purchases,
    coalesce(a.spend, 0)                 as spend,
    coalesce(a.points_earned, 0)         as points_earned,
    coalesce(a.dollars_raised, 0)        as dollars_raised,
    coalesce(a.referrals_sent, 0)        as referrals_sent
from dates as d
cross join "carton_caps"."gold"."dim_schools" as s
left join activity as a on a.school_id = s.school_id and a.activity_date = d.date_day
left join signups as n on n.school_id = s.school_id and n.signup_date = d.date_day