
    select * from "carton_caps"."gold"."fct_purchases" where not coalesce((price_paid > 0 and price_paid <= list_amount), false)
