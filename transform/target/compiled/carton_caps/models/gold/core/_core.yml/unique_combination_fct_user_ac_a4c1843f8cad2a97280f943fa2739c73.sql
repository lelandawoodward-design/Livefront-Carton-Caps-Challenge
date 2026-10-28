
    select user_id, activity_date, count(*) as n
    from "carton_caps"."gold"."fct_user_activity_daily"
    group by user_id, activity_date
    having count(*) > 1
