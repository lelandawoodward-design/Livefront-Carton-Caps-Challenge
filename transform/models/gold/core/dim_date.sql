-- One row per day from the first signup to the last purchase or invite.
with bounds as (
    select
        cast(least(
            (select min(signup_at) from {{ ref('users_current') }}),
            (select min(purchased_at) from {{ ref('purchases_checked') }} where dq_status = 'valid')
        ) as date) as first_day,
        cast(greatest(
            (select max(purchased_at) from {{ ref('purchases_checked') }} where dq_status = 'valid'),
            (select max(sent_at) from {{ ref('referrals_checked') }} where dq_status = 'valid'),
            (select max(signup_at) from {{ ref('users_current') }})
        ) as date) as last_day
),

days as (
    select cast(d as date) as date_day
    from bounds, generate_series(bounds.first_day, bounds.last_day, interval 1 day) as t(d)
)

select
    date_day,
    cast(date_trunc('week', date_day) as date)  as week_start,
    cast(date_trunc('month', date_day) as date) as month_start,
    dayname(date_day)                           as day_name,
    isodow(date_day)                            as day_of_week_number,  -- 1 = Monday
    isodow(date_day) in (6, 7)                  as is_weekend,
    -- US school year runs August to July, e.g. 2023-24
    case when month(date_day) >= 8
         then cast(year(date_day) as varchar) || '-' || right(cast(year(date_day) + 1 as varchar), 2)
         else cast(year(date_day) - 1 as varchar) || '-' || right(cast(year(date_day) as varchar), 2)
    end                                         as school_year
from days
