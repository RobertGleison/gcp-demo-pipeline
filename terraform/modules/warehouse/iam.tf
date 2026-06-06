# Dataset-scoped grants deferred from the iam layer (which only mints the SAs —
# bindings live with the resource they apply to). SA emails come from the iam
# layer's remote state. Non-authoritative *_iam_member, so these add grants
# without clobbering any other dataset access.
locals {
  dbt_member       = "serviceAccount:${var.dbt_sa_email}"
  pubsub_bq_member = "serviceAccount:${var.pubsub_bq_sa_email}"
}

# Pub/Sub -> BQ subscription writes landed rows into bronze.
resource "google_bigquery_dataset_iam_member" "pubsub_bq_bronze_editor" {
  project    = var.project_id
  dataset_id = module.bronze.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = local.pubsub_bq_member
}

# dbt reads bronze (silver models SELECT from it) — read-only, least privilege.
resource "google_bigquery_dataset_iam_member" "dbt_bronze_viewer" {
  project    = var.project_id
  dataset_id = module.bronze.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = local.dbt_member
}

# dbt builds silver + gold.
resource "google_bigquery_dataset_iam_member" "dbt_silver_editor" {
  project    = var.project_id
  dataset_id = module.silver.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = local.dbt_member
}

resource "google_bigquery_dataset_iam_member" "dbt_gold_editor" {
  project    = var.project_id
  dataset_id = module.gold.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = local.dbt_member
}
