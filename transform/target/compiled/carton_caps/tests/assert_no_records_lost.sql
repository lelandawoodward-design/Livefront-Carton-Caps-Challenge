-- Every purchase and referral that reached bronze ends up either in gold or in quarantine.
with checks as (
    select 'purchases' as entity,
           (select count(distinct record_key) from "carton_caps"."silver"."stg_purchases") as arrived,
           (select count(*) from "carton_caps"."gold"."fct_purchases")
         + (select count(*) from "carton_caps"."quality"."quarantine_purchases") as accounted_for
    union all
    select 'referrals',
           (select count(distinct record_key) from "carton_caps"."silver"."stg_referrals"),
           (select count(*) from "carton_caps"."gold"."fct_referrals")
         + (select count(*) from "carton_caps"."quality"."quarantine_referrals")
)

select * from checks where arrived <> accounted_for