
    select * from "carton_caps"."silver"."stg_districts" where not coalesce((median_household_income > 0), false)
