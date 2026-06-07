{{ config(
    materialized='table',
    schema=var('bronze'),
    incremental_strategy='merge',
    unique_key = 'message_id',
    partition_by={
      "field": "publish_time",
      "data_type": "timestamp",
      "granularity": "month"
    }
)}}

select
    subscription_name,
    message_id,
    publish_time,
    attributes,
    data as match_json
from {{ source('bronze', 'matches_bronze') }}


