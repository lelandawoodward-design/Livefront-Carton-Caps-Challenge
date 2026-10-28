-- One row per school per month: MAU, average DAU, stickiness and funds raised.
with daily as (
    select
        school_id,
        school_name,
        cast(date_trunc('month', activity_date) as date) as month,
        avg(active_users)    as avg_dau,
        sum(new_users)       as new_users,
        sum(purchases)       as purchases,
        sum(spend)           as spend,
        sum(points_earned)   as points_earned,
        sum(dollars_raised)  as dollars_raised,
        sum(referrals_sent)  as referrals_sent
    from "carton_caps"."gold"."school_daily_activity"
    group by all
),

monthly_active as (
    select school_id, activity_month as month, count(distinct user_id) as mau
    from "carton_caps"."gold"."fct_user_activity_daily"
    group by all
)

select
    d.month,
    d.school_id,
    d.school_name,
    coalesce(m.mau, 0)                                  as mau,
    round(d.avg_dau, 3)                                 as avg_dau,
    round(d.avg_dau / nullif(m.mau, 0), 4)              as stickiness,
    d.new_users,
    d.purchases,
    d.spend,
    d.points_earned,
    d.dollars_raised,
    sum(d.dollars_raised) over (partition by d.school_id order by d.month) as cumulative_dollars_raised,
    d.referrals_sent
from daily as d
left join monthly_active as m on m.school_id = d.school_id and m.month = d.month