# Pub/Sub ingest with a BigQuery subscription: topic -> DLQ + a no-code
# subscription that lands each message straight into BigQuery. Decouples the
# extractor from the warehouse and gives at-least-once delivery (dupes are made
# harmless downstream by dbt's idempotent MERGE).
#
# The owning layer (ingest) is responsible for:
#   - creating the target BQ table first (Pub/Sub will NOT create it),
#   - granting writer_sa_email bigquery.dataEditor on the dataset (warehouse layer),
#   - granting sa-extractor pubsub.publisher on the topic, and
#   - enabling pubsub.googleapis.com (apis.tf).

locals {
  dlq_topic_name        = coalesce(var.dlq_topic_name, "${var.topic_name}-dlq")
  subscription_name     = coalesce(var.subscription_name, "${var.topic_name}-bq")
  dlq_subscription_name = coalesce(var.dlq_subscription_name, "${local.dlq_topic_name}-pull")

  # Provider wants the table as projectId.datasetId.tableId.
  bq_table = "${var.project_id}.${var.bq_dataset_id}.${var.bq_table_id}"

  # Pub/Sub's per-project service agent. It (not the runtime SAs) does the
  # dead-lettering and, on the custom-SA path, impersonates writer_sa_email.
  pubsub_agent = "serviceAccount:service-${data.google_project.main.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

data "google_project" "main" {
  project_id = var.project_id
}

resource "google_pubsub_topic" "main" {
  project = var.project_id
  name    = var.topic_name
}

resource "google_pubsub_topic" "dlq" {
  project = var.project_id
  name    = local.dlq_topic_name
}

# No-code landing: Pub/Sub writes each message directly to BigQuery.
resource "google_pubsub_subscription" "bq" {
  project = var.project_id
  name    = local.subscription_name
  topic   = google_pubsub_topic.main.id

  ack_deadline_seconds       = var.ack_deadline_seconds
  message_retention_duration = var.message_retention_duration

  bigquery_config {
    table               = local.bq_table
    write_metadata      = var.write_metadata
    use_topic_schema    = var.use_topic_schema
    drop_unknown_fields = var.drop_unknown_fields

    # Write as the dedicated SA (least privilege) rather than the Pub/Sub
    # service agent. null => omit, and the service agent writes instead.
    service_account_email = var.writer_sa_email
  }

  # Repeatedly-failing messages (e.g. table schema mismatch) go to the DLQ
  # instead of redelivering forever.
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq.id
    max_delivery_attempts = var.max_delivery_attempts
  }

  # These bindings don't reference the subscription, so we can order them ahead
  # of it. (The subscriber binding below necessarily comes *after* the
  # subscription — it grants on the subscription itself — so it can't be ordered
  # here without a cycle; Terraform applies it immediately after creation.)
  depends_on = [
    google_pubsub_topic_iam_member.dlq_publisher,
    google_service_account_iam_member.pubsub_token_creator,
  ]
}

# DLQ has no real consumer; this pull subscription just holds dead-lettered
# messages so they can be inspected by hand. ttl="" stops Pub/Sub auto-deleting
# an idle subscription after 31 days.
resource "google_pubsub_subscription" "dlq" {
  project = var.project_id
  name    = local.dlq_subscription_name
  topic   = google_pubsub_topic.dlq.id

  message_retention_duration = var.dlq_retention_duration

  expiration_policy {
    ttl = ""
  }
}

# --- IAM the Pub/Sub service agent needs -------------------------------------

# Publish dead-lettered messages onto the DLQ topic.
resource "google_pubsub_topic_iam_member" "dlq_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.dlq.name
  role    = "roles/pubsub.publisher"
  member  = local.pubsub_agent
}

# Pull from the subscription it's dead-lettering (required by dead_letter_policy).
resource "google_pubsub_subscription_iam_member" "dlq_subscriber" {
  project      = var.project_id
  subscription = google_pubsub_subscription.bq.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_agent
}

# Custom-SA path: let the service agent mint tokens for writer_sa_email so the
# BigQuery subscription can write as that identity.
resource "google_service_account_iam_member" "pubsub_token_creator" {
  count = var.writer_sa_email == null ? 0 : 1

  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.writer_sa_email}"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.pubsub_agent
}
