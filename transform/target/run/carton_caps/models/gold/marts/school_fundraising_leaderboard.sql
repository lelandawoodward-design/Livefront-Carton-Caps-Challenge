
    

    create  table
      "carton_caps"."gold"."school_fundraising_leaderboard__dbt_tmp"
  
    
    as (
      -- School fundraising rankings by month, with movement and cumulative standing.
with ranked as (
    select
        month,
        school_id,
        school_name,
        dollars_raised,
        cumulative_dollars_raised,
        mau,
        rank() over (partition by month order by dollars_raised desc)            as monthly_rank,
        rank() over (partition by month order by cumulative_dollars_raised desc) as cumulative_rank,
        dollars_raised / nullif(sum(dollars_raised) over (partition by month), 0) as share_of_month
    from "carton_caps"."gold"."school_engagement_monthly"
)

select
    month,
    school_id,
    school_name,
    dollars_raised,
    monthly_rank,
    lag(monthly_rank) over (partition by school_id order by month)                  as previous_monthly_rank,
    lag(monthly_rank) over (partition by school_id order by month) - monthly_rank   as rank_change,
    cumulative_dollars_raised,
    cumulative_rank,
    round(dollars_raised / nullif(mau, 0), 2)                                       as dollars_per_active_user,
    round(share_of_month, 4)                                                        as share_of_month
from ranked
    );
    
  