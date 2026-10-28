-- Issue counts per check, with the share of the entity's records affected.
with record_counts as (
    select 'purchases' as entity, count(*) as records from {{ ref('purchases_checked') }}
    union all
    select 'referrals', count(*) from {{ ref('referrals_checked') }}
    union all
    select 'users', count(*) from {{ ref('users_current') }}
),

issue_counts as (
    select entity, check_name, count(*) as records_affected, sum(extra_copies) as extra_copies_dropped
    from {{ ref('dq_issues') }}
    group by all
)

select
    c.entity,
    c.check_name,
    c.severity,
    c.action,
    coalesce(i.records_affected, 0)                          as records_affected,
    i.extra_copies_dropped,
    round(coalesce(i.records_affected, 0) / r.records, 5)    as share_of_records,
    c.description
from {{ ref('dq_check_catalog') }} as c
inner join record_counts as r on r.entity = c.entity
left join issue_counts as i on i.entity = c.entity and i.check_name = c.check_name
order by c.entity, records_affected desc, c.check_name
