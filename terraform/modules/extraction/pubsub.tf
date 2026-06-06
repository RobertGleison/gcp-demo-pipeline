# The landing table the BigQuery subscription writes to. Pub/Sub does NOT create
# it, so it must exist first — hence the module's depends_on below. Schema is the
# Pub/Sub metadata layout (write_metadata=true): the message body lands whole in
# `data` (JSON text) and dbt parses it later; `attributes` holds match_id /
# platform / queue_id as a JSON object.
resource "google_bigquery_table" "matches_bronze" {
  project    = var.project_id
  dataset_id = var.bronze_dataset_id
  table_id   = var.bronze_table_id

  # Study project — allow `terraform destroy` to remove the table.
  deletion_protection = false

  # Partition by ingest time; each daily partition self-expires (bronze is
  # disposable — the replayable source of truth is Pub/Sub).
  time_partitioning {
    type          = "DAY"
    field         = "publish_time"
    expiration_ms = var.bronze_partition_expiration_days * 24 * 60 * 60 * 1000
  }

  schema = jsonencode([
    { name = "subscription_name", type = "STRING", mode = "NULLABLE" },
    { name = "message_id", type = "STRING", mode = "NULLABLE" },
    { name = "publish_time", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "attributes", type = "JSON", mode = "NULLABLE" },
    { name = "data", type = "STRING", mode = "NULLABLE" },
  ])
}

# Topic + DLQ + BigQuery subscription. Writes as sa-pubsub-bq (custom-SA path);
# that SA already has bigquery.dataEditor on bronze (granted in the warehouse layer).
module "pubsub" {
  source = "./pubsub"

  project_id      = var.project_id
  topic_name      = var.topic_name
  bq_dataset_id   = var.bronze_dataset_id
  bq_table_id     = google_bigquery_table.matches_bronze.table_id
  writer_sa_email = var.pubsub_bq_sa_email

  # Table must exist before the subscription targets it.
  depends_on = [
    google_bigquery_table.matches_bronze,
  ]
}

# The extractor publishes matches to the topic. Resource-scoped (topic only) —
# least privilege, per the design's IAM section.
resource "google_pubsub_topic_iam_member" "extractor_publisher" {
  project = var.project_id
  topic   = module.pubsub.topic_name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.extractor_sa_email}"
}
