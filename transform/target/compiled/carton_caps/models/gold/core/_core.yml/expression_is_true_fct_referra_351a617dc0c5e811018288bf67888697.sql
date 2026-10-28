
    select * from "carton_caps"."gold"."fct_referrals" where not coalesce((not is_qualified or is_converted), false)
