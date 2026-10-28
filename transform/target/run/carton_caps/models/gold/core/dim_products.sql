
    

    create  table
      "carton_caps"."gold"."dim_products__dbt_tmp"
  
    
    as (
      select
    product_id,
    product_name,
    category,
    list_price,
    points_per_dollar,
    launched_at
from "carton_caps"."silver"."stg_products"
    );
    
  