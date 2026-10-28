
    select * from "carton_caps"."gold"."fct_purchases" where not coalesce((quantity > 0), false)
