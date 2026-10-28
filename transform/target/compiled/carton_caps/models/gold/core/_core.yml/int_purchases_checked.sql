
-- Fixture for int_purchases_checked
select cast(null as character varying(256)) as "record_key", cast(null as BIGINT) as "purchase_id", 
    
    cast(3 as INTEGER)
 as "user_id", cast(null as INTEGER) as "product_id", cast(null as INTEGER) as "quantity", cast(null as DECIMAL(12,2)) as "price_paid", cast(null as INTEGER) as "points_reported", cast(null as INTEGER) as "points_expected", 
    
    cast('2024-01-21 10:00:00' as TIMESTAMP)
 as "purchased_at", cast(null as character varying(256)) as "natural_key", cast(null as BIGINT) as "copies", cast(null as DATE) as "first_batch_id", cast(null as DATE) as "last_batch_id", cast(null as VARCHAR[]) as "dq_issues", cast(null as character varying(256)) as "dq_issues_text", 
    
    cast('valid' as character varying)
 as "dq_status", cast(null as DATE) as "evaluated_batch_id"