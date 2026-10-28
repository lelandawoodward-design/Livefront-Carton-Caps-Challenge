
    select * from "carton_caps"."gold"."cohort_retention" where not coalesce((retention_rate between 0 and 1), false)
