-- One row per detected data-quality issue, joined to the check catalog for severity and action.
with issues as (
    select 'purchases' as entity, record_key as record_id, unnest(dq_issues) as check_name,
           last_batch_id as batch_id, copies - 1 as extra_copies
    from {{ ref('purchases_checked') }}
    union all
    select 'referrals', record_key, unnest(dq_issues), last_batch_id, null
    from {{ ref('referrals_checked') }}
    union all
    select 'users', cast(user_id as varchar), unnest(dq_issues), snapshot_batch_id, null
    from {{ ref('users_current') }}
)

select
    i.entity,
    i.record_id,
    i.check_name,
    c.severity,
    c.action,
    case when i.check_name = 'exact_duplicate' then i.extra_copies end as extra_copies,
    i.batch_id,
    c.description
from issues as i
left join {{ ref('dq_check_catalog') }} as c
    on c.entity = i.entity and c.check_name = i.check_name
