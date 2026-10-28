
    

    create  table
      "carton_caps"."gold"."fct_user_activity_daily__dbt_tmp"
  
    
    as (
      -- One row per user per day with any activity: a valid purchase or a valid invite sent.
-- This is the definition of "active" used by every DAU/MAU and retention metric.
with purchases as (
    select
        user_id,
        purchase_date                  as activity_date,
        count(*)                       as purchases,
        sum(price_paid)                as spend,
        sum(points_earned)             as points_earned,
        sum(dollars_raised)            as dollars_raised
    from "carton_caps"."gold"."fct_purchases"
    group by all
),

invites as (
    select
        referrer_user_id               as user_id,
        cast(sent_at as date)          as activity_date,
        count(*)                       as referrals_sent
    from "carton_caps"."gold"."fct_referrals"
    group by all
),

combined as (
    select
        coalesce(p.user_id, i.user_id)             as user_id,
        coalesce(p.activity_date, i.activity_date) as activity_date,
        coalesce(p.purchases, 0)                   as purchases,
        coalesce(p.spend, 0)                       as spend,
        coalesce(p.points_earned, 0)               as points_earned,
        coalesce(p.dollars_raised, 0)              as dollars_raised,
        coalesce(i.referrals_sent, 0)              as referrals_sent
    from purchases as p
    full outer join invites as i
        on i.user_id = p.user_id and i.activity_date = p.activity_date
)

select
    c.user_id,
    u.school_id,
    c.activity_date,
    cast(date_trunc('month', c.activity_date) as date) as activity_month,
    c.purchases,
    c.spend,
    c.points_earned,
    c.dollars_raised,
    c.referrals_sent
from combined as c
inner join "carton_caps"."gold"."dim_users" as u on u.user_id = c.user_id
    );
    
  