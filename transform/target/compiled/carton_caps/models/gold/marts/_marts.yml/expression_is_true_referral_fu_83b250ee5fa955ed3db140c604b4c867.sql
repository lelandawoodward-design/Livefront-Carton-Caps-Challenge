
    select * from "carton_caps"."gold"."referral_funnel_monthly" where not coalesce((invites >= clicked and clicked >= converted and converted >= qualified), false)
