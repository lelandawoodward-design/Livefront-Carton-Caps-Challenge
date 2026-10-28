
    
    

with child as (
    select referred_user_id as from_field
    from "carton_caps"."gold"."fct_referrals"
    where referred_user_id is not null
),

parent as (
    select user_id as to_field
    from "carton_caps"."gold"."dim_users"
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


