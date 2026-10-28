{# Use the configured schema name as-is (silver, gold, quality) instead of prefixing the target schema. #}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}{{ target.schema }}{%- else -%}{{ custom_schema_name | trim }}{%- endif -%}
{%- endmacro %}


{# Keyed hash of a normalised email: lower-cased, trimmed, and with any +tag removed,
   so "Jane.Doe+cc@Email.com" and "jane.doe@email.com" hash the same. #}
{% macro email_hash(column) -%}
    case when nullif(trim({{ column }}), '') is not null then
        sha256('{{ var("email_hash_salt") }}' || regexp_replace(lower(trim({{ column }})), '\+[^@]*@', '@'))
    end
{%- endmacro %}


{# dq_status from an issue list: quarantined if any issue's catalog action is 'quarantine'. #}
{% macro dq_status(issues_column, entity) -%}
    case
        when list_has_any({{ issues_column }}, (
            select list(check_name) from {{ ref('dq_check_catalog') }}
            where entity = '{{ entity }}' and action = 'quarantine'
        )) then 'quarantined'
        else 'valid'
    end
{%- endmacro %}


{# The newest batch ingested for any entity: identifies the current run for incremental bookkeeping. #}
{% macro latest_batch_id() -%}
    (select max(batch_id) from {{ source('meta', 'ingested_files') }})
{%- endmacro %}


{# Dollars raised for a number of points. #}
{% macro points_to_dollars(points) -%}
    cast(round({{ points }} / {{ var('points_per_dollar_raised') }}, 2) as decimal(18, 2))
{%- endmacro %}
