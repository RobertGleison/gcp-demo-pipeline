{#
  Use the custom schema name verbatim as the BigQuery dataset.

  dbt's built-in behaviour concatenates <target.schema>_<custom_schema>
  (e.g. profile dataset `silver` + `schema='bronze'` -> `silver_bronze`).
  For a medallion layout we want models to land in exactly the dataset named
  by their `schema` config (bronze / silver / gold), so we return the custom
  name as-is and fall back to the profile's default dataset when none is set.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
