
    select month, school_id, count(*) as n
    from "carton_caps"."gold"."school_fundraising_leaderboard"
    group by month, school_id
    having count(*) > 1
