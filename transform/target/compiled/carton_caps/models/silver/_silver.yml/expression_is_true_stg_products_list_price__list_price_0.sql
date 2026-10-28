
    select * from "carton_caps"."silver"."stg_products" where not coalesce((list_price > 0), false)
