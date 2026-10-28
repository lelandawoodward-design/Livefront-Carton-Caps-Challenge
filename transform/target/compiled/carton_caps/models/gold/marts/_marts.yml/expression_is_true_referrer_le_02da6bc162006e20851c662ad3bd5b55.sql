
    select * from "carton_caps"."gold"."referrer_leaderboard" where not coalesce((network_size >= direct_referrals), false)
