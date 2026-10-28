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
from {{ ref('schools_current') }} as s
left join {{ ref('districts_current') }} as d on d.city = s.city and d.state = s.state
