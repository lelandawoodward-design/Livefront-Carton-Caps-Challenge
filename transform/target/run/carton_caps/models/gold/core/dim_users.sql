
    

    create  table
      "carton_caps"."gold"."dim_users__dbt_tmp"
  
    
    as (
      -- Valid users with how they were acquired and where they sit in the referral network.
with recursive

users as (
    select * from "carton_caps"."silver"."stg_users" where dq_status = 'valid'
),

-- The valid invite each referred user joined through (last touch).
referral_links as (
    select
        referred_user_id as user_id,
        referrer_user_id,
        referral_id
    from "carton_caps"."silver"."int_referrals_checked"
    where dq_status = 'valid' and status = 'converted'
    qualify row_number() over (partition by referred_user_id order by converted_at, referral_id) = 1
),

-- Generation 0 is an organic user; each referral hop adds one.
generations (user_id, generation, root_user_id) as (
    select u.user_id, 0, u.user_id
    from users as u
    where u.user_id not in (select user_id from referral_links)
    union all
    select l.user_id, g.generation + 1, g.root_user_id
    from referral_links as l
    inner join generations as g on g.user_id = l.referrer_user_id
    where g.generation < 50
),

first_purchases as (
    select user_id, min(purchased_at) as first_purchase_at
    from "carton_caps"."silver"."int_purchases_checked"
    where dq_status = 'valid'
    group by user_id
)

select
    u.user_id,
    u.school_id,
    u.user_type,
    u.signup_at,
    cast(u.signup_at as date)                          as signup_date,
    cast(date_trunc('month', u.signup_at) as date)     as signup_cohort_month,
    case when l.user_id is null then 'organic' else 'referral' end as acquisition_channel,
    l.referrer_user_id,
    l.referral_id                                      as joined_via_referral_id,
    g.generation                                       as referral_generation,
    g.root_user_id                                     as root_user_id,
    f.first_purchase_at,
    f.first_purchase_at is not null                    as is_activated,
    date_diff('day', u.signup_at, f.first_purchase_at) as days_to_first_purchase,
    u.email_hash,
    u.has_shared_email
from users as u
left join referral_links as l on l.user_id = u.user_id
left join generations as g on g.user_id = u.user_id
left join first_purchases as f on f.user_id = u.user_id
    );
    
  