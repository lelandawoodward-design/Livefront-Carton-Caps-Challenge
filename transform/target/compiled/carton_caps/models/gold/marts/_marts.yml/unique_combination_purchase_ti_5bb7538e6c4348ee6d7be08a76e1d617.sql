
    select day_of_week_number, hour_of_day, count(*) as n
    from "carton_caps"."gold"."purchase_time_heatmap"
    group by day_of_week_number, hour_of_day
    having count(*) > 1
