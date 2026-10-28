
-- Fixture for stg_purchases
select 
    
    cast('1' as character varying)
 as "record_key", 
    
    cast(1 as BIGINT)
 as "purchase_id", 
    
    cast(10 as INTEGER)
 as "user_id", 
    
    cast(100 as INTEGER)
 as "product_id", 
    
    cast(2 as INTEGER)
 as "quantity", 
    
    cast(10.0 as DECIMAL(12,2))
 as "price_paid", 
    
    cast(20 as INTEGER)
 as "points_reported", 
    
    cast('2024-01-05 10:00:00' as TIMESTAMP)
 as "purchased_at", 
    
    cast('Friday' as character varying)
 as "day_of_week_reported", 
    
    cast(10 as INTEGER)
 as "hour_of_day_reported", 
    
    cast('a' as character varying)
 as "content_hash", 
    
    cast('2024-01-31' as DATE)
 as "_batch_id", 
    
    cast(1 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file", 
    
    cast('n1' as character varying)
 as "natural_key"
union all
select 
    
    cast('1' as character varying)
 as "record_key", 
    
    cast(1 as BIGINT)
 as "purchase_id", 
    
    cast(10 as INTEGER)
 as "user_id", 
    
    cast(100 as INTEGER)
 as "product_id", 
    
    cast(2 as INTEGER)
 as "quantity", 
    
    cast(10.0 as DECIMAL(12,2))
 as "price_paid", 
    
    cast(20 as INTEGER)
 as "points_reported", 
    
    cast('2024-01-05 10:00:00' as TIMESTAMP)
 as "purchased_at", 
    
    cast('Friday' as character varying)
 as "day_of_week_reported", 
    
    cast(10 as INTEGER)
 as "hour_of_day_reported", 
    
    cast('a' as character varying)
 as "content_hash", 
    
    cast('2024-01-31' as DATE)
 as "_batch_id", 
    
    cast(2 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file", 
    
    cast('n1' as character varying)
 as "natural_key"
union all
select 
    
    cast('2' as character varying)
 as "record_key", 
    
    cast(2 as BIGINT)
 as "purchase_id", 
    
    cast(10 as INTEGER)
 as "user_id", 
    
    cast(100 as INTEGER)
 as "product_id", 
    
    cast(2 as INTEGER)
 as "quantity", 
    
    cast(10.0 as DECIMAL(12,2))
 as "price_paid", 
    
    cast(20 as INTEGER)
 as "points_reported", 
    
    cast('2024-01-05 10:00:00' as TIMESTAMP)
 as "purchased_at", 
    
    cast('Friday' as character varying)
 as "day_of_week_reported", 
    
    cast(10 as INTEGER)
 as "hour_of_day_reported", 
    
    cast('b' as character varying)
 as "content_hash", 
    
    cast('2024-01-31' as DATE)
 as "_batch_id", 
    
    cast(3 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file", 
    
    cast('n1' as character varying)
 as "natural_key"
union all
select 
    
    cast('3' as character varying)
 as "record_key", 
    
    cast(3 as BIGINT)
 as "purchase_id", 
    
    cast(10 as INTEGER)
 as "user_id", 
    
    cast(100 as INTEGER)
 as "product_id", 
    
    cast(1 as INTEGER)
 as "quantity", 
    
    cast(4.99 as DECIMAL(12,2))
 as "price_paid", 
    
    cast(30 as INTEGER)
 as "points_reported", 
    
    cast('2024-01-06 11:00:00' as TIMESTAMP)
 as "purchased_at", 
    
    cast('Saturday' as character varying)
 as "day_of_week_reported", 
    
    cast(11 as INTEGER)
 as "hour_of_day_reported", 
    
    cast('c' as character varying)
 as "content_hash", 
    
    cast('2024-01-31' as DATE)
 as "_batch_id", 
    
    cast(4 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file", 
    
    cast('n3' as character varying)
 as "natural_key"
union all
select 
    
    cast('4' as character varying)
 as "record_key", 
    
    cast(4 as BIGINT)
 as "purchase_id", 
    
    cast(10 as INTEGER)
 as "user_id", 
    
    cast(999 as INTEGER)
 as "product_id", 
    
    cast(1 as INTEGER)
 as "quantity", 
    
    cast(5.0 as DECIMAL(12,2))
 as "price_paid", 
    
    cast(5 as INTEGER)
 as "points_reported", 
    
    cast('2024-01-07 12:00:00' as TIMESTAMP)
 as "purchased_at", 
    
    cast('Sunday' as character varying)
 as "day_of_week_reported", 
    
    cast(12 as INTEGER)
 as "hour_of_day_reported", 
    
    cast('d' as character varying)
 as "content_hash", 
    
    cast('2024-01-31' as DATE)
 as "_batch_id", 
    
    cast(5 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file", 
    
    cast('n4' as character varying)
 as "natural_key"
union all
select 
    
    cast('5' as character varying)
 as "record_key", 
    
    cast(5 as BIGINT)
 as "purchase_id", 
    
    cast(10 as INTEGER)
 as "user_id", 
    
    cast(100 as INTEGER)
 as "product_id", 
    
    cast(1 as INTEGER)
 as "quantity", 
    
    cast(5.0 as DECIMAL(12,2))
 as "price_paid", 
    
    cast(10 as INTEGER)
 as "points_reported", 
    
    cast('2023-12-01 09:00:00' as TIMESTAMP)
 as "purchased_at", 
    
    cast('Friday' as character varying)
 as "day_of_week_reported", 
    
    cast(9 as INTEGER)
 as "hour_of_day_reported", 
    
    cast('e' as character varying)
 as "content_hash", 
    
    cast('2024-01-31' as DATE)
 as "_batch_id", 
    
    cast(6 as BIGINT)
 as "_row_number", cast(null as character varying(256)) as "_source_file", 
    
    cast('n5' as character varying)
 as "natural_key"