-- Every purchase and referral that reached bronze ends up either in gold or in quarantine.
with checks as (
    select 'purchases' as entity,
           (select count(distinct record_key) from {{ ref('purchases_typed') }}) as arrived,
           (select count(*) from {{ ref('fct_purchases') }})
         + (select count(*) from {{ ref('quarantine_purchases') }}) as accounted_for
    union all
    select 'referrals',
           (select count(distinct record_key) from {{ ref('referrals_typed') }}),
           (select count(*) from {{ ref('fct_referrals') }})
         + (select count(*) from {{ ref('quarantine_referrals') }})
)

select * from checks where arrived <> accounted_for
