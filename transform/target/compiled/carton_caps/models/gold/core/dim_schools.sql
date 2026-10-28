-- Schools with their district's income level.
select
    s.school_id,
    s.school_name,
    s.city,
    s.state,
    d.district,
    d.income_level,
    d.median_household_income,
    s.created_at
from "carton_caps"."silver"."stg_schools" as s
left join "carton_caps"."silver"."stg_districts" as d on d.city = s.city and d.state = s.state