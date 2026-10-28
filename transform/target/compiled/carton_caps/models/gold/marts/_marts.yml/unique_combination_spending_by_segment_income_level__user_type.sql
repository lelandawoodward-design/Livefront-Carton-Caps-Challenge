
    select income_level, user_type, count(*) as n
    from "carton_caps"."gold"."spending_by_segment"
    group by income_level, user_type
    having count(*) > 1
