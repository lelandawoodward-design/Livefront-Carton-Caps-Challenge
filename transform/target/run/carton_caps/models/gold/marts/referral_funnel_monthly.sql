
    

    create  table
      "carton_caps"."gold"."referral_funnel_monthly__dbt_tmp"
  
    
    as (
      -- Referral funnel by the month invites were sent and the referrer's invite volume
-- (plus 'all'): sent -> clicked -> converted -> qualified, bonus cost, and what
-- the referred users went on to raise.
with invites as (
    select *, referrer_segment as segment from "carton_caps"."gold"."fct_referrals"
    union all by name
    select *, 'all' as segment from "carton_caps"."gold"."fct_referrals"
),

referred_user_funds as (
    select user_id, sum(dollars_raised) as dollars_raised
    from "carton_caps"."gold"."fct_purchases"
    group by all
)

select
    i.sent_month,
    i.segment                                                          as referrer_segment,
    count(*)                                                           as invites,
    count(*) filter (where i.is_clicked)                               as clicked,
    count(*) filter (where i.is_converted)                             as converted,
    count(*) filter (where i.is_qualified)                             as qualified,
    round(count(*) filter (where i.is_clicked) / count(*), 4)          as click_rate,
    round(count(*) filter (where i.is_converted) / count(*), 4)        as conversion_rate,
    round(count(*) filter (where i.is_converted)
          / nullif(count(*) filter (where i.is_clicked), 0), 4)        as click_to_conversion_rate,
    count(*) filter (where i.is_converted and not i.is_qualification_window_complete)
                                                                       as converted_still_in_window,
    -- Only conversions whose qualification window has closed, so recent months aren't understated.
    round(count(*) filter (where i.is_qualified and i.is_qualification_window_complete)
          / nullif(count(*) filter (where i.is_qualification_window_complete), 0), 4)
                                                                       as qualification_rate,
    round(median(i.hours_to_convert) filter (where i.is_converted), 2) as median_hours_to_convert,
    sum(i.bonus_usd)                                                   as bonus_cost_usd,
    coalesce(sum(f.dollars_raised) filter (where i.is_converted), 0)   as dollars_raised_by_referred_users,
    round(coalesce(sum(f.dollars_raised) filter (where i.is_converted), 0)
          / nullif(sum(i.bonus_usd), 0), 4)                            as dollars_raised_per_bonus_dollar
from invites as i
left join referred_user_funds as f on f.user_id = i.referred_user_id
group by all
    );
    
  