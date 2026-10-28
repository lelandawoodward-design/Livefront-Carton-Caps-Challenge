
-- Fixture for stg_products
select 
    
    cast(100 as INTEGER)
 as "product_id", cast(null as character varying(256)) as "product_name", cast(null as character varying(256)) as "category", 
    
    cast(5.0 as DECIMAL(10,2))
 as "list_price", 
    
    cast(2 as INTEGER)
 as "points_per_dollar", cast(null as TIMESTAMP) as "launched_at", cast(null as DATE) as "snapshot_batch_id"