
    select month, category, user_type, count(*) as n
    from "carton_caps"."gold"."product_category_monthly"
    group by month, category, user_type
    having count(*) > 1
