-- Monthly signup cohorts: share of each cohort active k months after signup,
-- split by acquisition channel (plus 'all'). Month 0 is the signup month.
-- Only months fully inside the data are included.
with users as (
    select user_id, signup_cohort_month as cohort_month, acquisition_channel as channel
    from "carton_caps"."gold"."dim_users"
    union all
    select user_id, signup_cohort_month, 'all'
    from "carton_caps"."gold"."dim_users"
),

last_month as (
    select max(month_start) as month from "carton_caps"."gold"."dim_date"
),

cohorts as (
    select cohort_month, channel, count(*) as cohort_size
    from users
    group by all
),

offsets as (
    select c.cohort_month, c.channel, c.cohort_size, k.months_since_signup
    from cohorts as c
    cross join range(0, 120) as k(months_since_signup)
    where c.cohort_month + to_months(cast(k.months_since_signup as integer)) <= (select month from last_month)
),

user_months as (
    select user_id, activity_month, sum(points_earned) as points_earned
    from "carton_caps"."gold"."fct_user_activity_daily"
    group by all
),

cohort_activity as (
    select
        u.cohort_month,
        u.channel,
        date_diff('month', u.cohort_month, m.activity_month) as months_since_signup,
        count(distinct u.user_id)                            as active_users,
        sum(m.points_earned)                                 as points_earned
    from users as u
    inner join user_months as m on m.user_id = u.user_id
    group by all
)

select
    o.cohort_month,
    o.channel,
    o.months_since_signup,
    o.cohort_size,
    coalesce(a.active_users, 0)                                   as active_users,
    round(coalesce(a.active_users, 0) / o.cohort_size, 4)         as retention_rate,
    round(cast(round(sum(coalesce(a.points_earned, 0)) over w / 100, 2) as decimal(18, 2)) / o.cohort_size, 4)
                                                                  as cumulative_dollars_raised_per_user
from offsets as o
left join cohort_activity as a
    on a.cohort_month = o.cohort_month
   and a.channel = o.channel
   and a.months_since_signup = o.months_since_signup
window w as (partition by o.cohort_month, o.channel order by o.months_since_signup)