
    
    

with child as (
    select product_id as from_field
    from "carton_caps"."gold"."fct_purchases"
    where product_id is not null
),

parent as (
    select product_id as to_field
    from "carton_caps"."gold"."dim_products"
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


