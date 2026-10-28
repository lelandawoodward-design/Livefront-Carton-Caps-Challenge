
    select * from "carton_caps"."gold"."dim_users" where not coalesce(((referral_generation = 0) = (acquisition_channel = 'organic')), false)
