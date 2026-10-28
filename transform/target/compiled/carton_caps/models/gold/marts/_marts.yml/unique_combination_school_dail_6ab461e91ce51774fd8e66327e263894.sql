
    select activity_date, school_id, count(*) as n
    from "carton_caps"."gold"."school_daily_activity"
    group by activity_date, school_id
    having count(*) > 1
