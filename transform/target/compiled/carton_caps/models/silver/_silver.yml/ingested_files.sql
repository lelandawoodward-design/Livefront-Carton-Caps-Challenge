
-- Fixture for ingested_files
select cast(null as character varying(256)) as "file_path", 
    
    cast('2024-02-29' as DATE)
 as "batch_id", cast(null as character varying(256)) as "entity", cast(null as character varying(256)) as "sha256", cast(null as BIGINT) as "row_count", cast(null as TIMESTAMP) as "ingested_at"