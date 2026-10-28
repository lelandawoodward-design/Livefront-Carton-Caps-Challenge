-- Sample queries against warehouse/carton_caps.duckdb.
-- Run them all with `python -m pipeline report`, or paste any one into the DuckDB CLI:
--   duckdb warehouse/carton_caps.duckdb
-- Each query starts with a "-- name:" line.

-- name: Data quality: what the pipeline caught and what it did about it
select entity, check_name, severity, action, records_affected, extra_copies_dropped
from quality.dq_summary
where records_affected > 0
order by entity, records_affected desc;

-- name: Fundraising leaderboard for the latest month
select monthly_rank, school_name, dollars_raised, rank_change, cumulative_rank,
       cumulative_dollars_raised, dollars_per_active_user
from gold.school_fundraising_leaderboard
where month = (select max(month) from gold.school_fundraising_leaderboard)
order by monthly_rank
limit 10;

-- name: Engagement by month across all schools (DAU, MAU, stickiness)
select month,
       sum(mau)                                as mau,
       round(sum(avg_dau), 1)                  as avg_dau,
       round(sum(avg_dau) / sum(mau), 3)       as stickiness,
       sum(new_users)                          as new_users,
       sum(dollars_raised)                     as dollars_raised
from gold.school_engagement_monthly
group by month
order by month;

-- name: Daily active users for the busiest school, last 14 days
select activity_date, school_name, active_users, new_users, purchases, dollars_raised
from gold.school_daily_activity
where school_id = (select school_id from gold.school_fundraising_leaderboard
                   where month = (select max(month) from gold.school_fundraising_leaderboard)
                   order by cumulative_rank limit 1)
order by activity_date desc
limit 14;

-- name: Retention by acquisition channel (2023 signup cohorts, share active k months after signup)
select channel,
       sum(cohort_size) filter (where months_since_signup = 0)                                         as users,
       round(sum(active_users) filter (where months_since_signup = 1) / sum(cohort_size) filter (where months_since_signup = 1), 3) as month_1,
       round(sum(active_users) filter (where months_since_signup = 3) / sum(cohort_size) filter (where months_since_signup = 3), 3) as month_3,
       round(sum(active_users) filter (where months_since_signup = 6) / sum(cohort_size) filter (where months_since_signup = 6), 3) as month_6
from gold.cohort_retention
where cohort_month < date '2024-01-01'
group by channel
order by channel;

-- name: Referral funnel by referrer volume (all months)
select referrer_segment,
       sum(invites)                                         as invites,
       round(sum(clicked) / sum(invites), 3)                as click_rate,
       round(sum(converted) / sum(invites), 3)              as conversion_rate,
       sum(qualified)                                       as qualified,
       sum(bonus_cost_usd)                                  as bonus_cost_usd,
       sum(dollars_raised_by_referred_users)                as raised_by_referred_users
from gold.referral_funnel_monthly
group by referrer_segment
order by referrer_segment = 'all', referrer_segment;

-- name: Viral growth by month
select month, active_users, signups, referral_signups, referral_share_of_signups,
       invites_per_active_user, invite_conversion_rate, k_factor
from gold.referral_growth_monthly
order by month;

-- name: Top referrers by the network they started
select network_rank, user_id, user_type, invites, direct_referrals, network_size,
       deepest_chain, network_dollars_raised
from gold.referrer_leaderboard
order by network_rank
limit 5;

-- name: Spending by district income level and user type
select income_level, user_type, buying_users, purchases_per_buyer, units_per_purchase,
       avg_list_price_per_unit, spend_per_purchase, promo_share, dollars_raised_per_user
from gold.spending_by_segment
order by case income_level when 'low' then 1 when 'middle' then 2 else 3 end, user_type;

-- name: Funds raised per user by school district
select s.district, s.income_level, s.median_household_income,
       count(distinct s.school_id)                                  as schools,
       count(distinct u.user_id)                                    as users,
       coalesce(sum(p.dollars_raised), 0)                           as dollars_raised,
       round(coalesce(sum(p.dollars_raised), 0) / count(distinct u.user_id), 2) as dollars_raised_per_user
from gold.dim_schools as s
join gold.dim_users as u on u.school_id = s.school_id
left join gold.fct_purchases as p on p.user_id = u.user_id
group by all
order by dollars_raised_per_user desc
limit 10;

-- name: Category mix by user type (share of spend, all months)
select user_type, category, round(sum(spend), 2) as spend,
       round(sum(spend) / sum(sum(spend)) over (partition by user_type), 3) as share_of_spend
from gold.product_category_monthly
group by user_type, category
order by user_type, share_of_spend desc;

-- name: Busiest shopping times
select day_name, hour_of_day, purchases, share_of_purchases
from gold.purchase_time_heatmap
order by purchases desc
limit 8;
