
    select month, school_id, count(*) as n
    from "carton_caps"."gold"."school_engagement_monthly"
    group by month, school_id
    having count(*) > 1
