
    

    create  table
      "carton_caps"."gold"."purchase_time_heatmap__dbt_tmp"
  
    
    as (
      -- Purchases by day of week and hour (all 168 cells, zero-filled).
with counts as (
    select day_of_week_number, hour_of_day, count(*) as purchases
    from "carton_caps"."gold"."fct_purchases"
    group by all
),

grid as (
    select d.day_of_week_number, h.hour_of_day
    from range(1, 8) as d(day_of_week_number)
    cross join range(0, 24) as h(hour_of_day)
)

select
    cast(g.day_of_week_number as integer)                 as day_of_week_number,
    ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][g.day_of_week_number]
                                                          as day_name,
    g.day_of_week_number in (6, 7)                        as is_weekend,
    cast(g.hour_of_day as integer)                        as hour_of_day,
    coalesce(c.purchases, 0)                              as purchases,
    round(coalesce(c.purchases, 0) / sum(coalesce(c.purchases, 0)) over (), 5) as share_of_purchases
from grid as g
left join counts as c
    on c.day_of_week_number = g.day_of_week_number and c.hour_of_day = g.hour_of_day
    );
    
  