# pubsub

Pub/Sub ingest with a **BigQuery subscription**: a topic plus a DLQ and a no-code
subscription that lands each message straight into BigQuery. Decouples the
producer from the warehouse and gives at-least-once delivery (dupes are made
harmless downstream by dbt's idempotent MERGE).

The owning layer must: create the target BQ table first (Pub/Sub will **not**
create it), grant `writer_sa_email` `bigquery.dataEditor` on the dataset, grant
the producer `pubsub.publisher` on the topic, and enable `pubsub.googleapis.com`.

## Usage

```hcl
module "pubsub" {
  source = "./pubsub"

  project_id      = var.project_id
  topic_name      = "lol-matches"
  bq_dataset_id   = var.bronze_dataset_id
  bq_table_id     = google_bigquery_table.matches_bronze.table_id
  writer_sa_email = var.pubsub_bq_sa_email

  depends_on = [google_bigquery_table.matches_bronze]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| google | ~> 6.0 (inherited from the root) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | Project that owns the topics and subscriptions. | `string` | n/a | yes |
| topic_name | Main topic the producer publishes to. | `string` | n/a | yes |
| bq_dataset_id | Dataset holding the landing table. | `string` | n/a | yes |
| dlq_topic_name | Dead-letter topic name. | `string` | `"<topic_name>-dlq"` | no |
| subscription_name | BigQuery subscription name. | `string` | `"<topic_name>-bq"` | no |
| dlq_subscription_name | Pull subscription on the DLQ. | `string` | `"<dlq_topic_name>-pull"` | no |
| bq_table_id | Existing table the subscription writes to (created by the owning layer). | `string` | `"matches_bronze"` | no |
| writer_sa_email | SA the subscription writes as; `null` => Pub/Sub service agent writes. | `string` | `null` | no |
| write_metadata | Write Pub/Sub metadata columns alongside the body. | `bool` | `true` | no |
| use_topic_schema | Map the topic schema onto columns. | `bool` | `false` | no |
| drop_unknown_fields | Drop fields absent from the table (only with `use_topic_schema`). | `bool` | `false` | no |
| ack_deadline_seconds | Seconds before redelivery. | `number` | `60` | no |
| max_delivery_attempts | Deliveries before dead-lettering. Validated `>= 5`. | `number` | `5` | no |
| message_retention_duration | How long the BQ subscription retains unacked messages. | `string` | `"604800s"` | no |
| dlq_retention_duration | How long the DLQ subscription retains messages. | `string` | `"604800s"` | no |

## Outputs

| Name | Description |
|------|-------------|
| topic_id | Fully-qualified main topic ID. |
| topic_name | Main topic short name. |
| dlq_topic_id | Dead-letter topic ID. |
| subscription_name | BigQuery subscription name. |
| dlq_subscription_name | DLQ pull subscription name. |
