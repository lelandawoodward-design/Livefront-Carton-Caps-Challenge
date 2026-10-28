-- Every check a model can emit must be documented in the check catalog.
select distinct entity, check_name
from {{ ref('dq_issues') }}
where severity is null
