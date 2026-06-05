# The three medallion datasets. Table-level partitioning/clustering is set by
# the writers (Pub/Sub BQ subscription for raw, dbt for staging/marts).
locals {
  # raw is disposable — it's the replayable source of truth landed from Pub/Sub,
  # so its tables self-expire after 30 days.
  raw_table_expiration_ms = 30 * 24 * 60 * 60 * 1000
}

module "raw" {
  source = "../bigquery_datasets"

  project_id                  = var.project_id
  dataset_id                  = var.raw_dataset
  location                    = var.bq_location
  description                 = "Bronze: raw match JSON landed by the Pub/Sub BigQuery subscription."
  default_table_expiration_ms = local.raw_table_expiration_ms
}

module "staging" {
  source = "../bigquery_datasets"

  project_id  = var.project_id
  dataset_id  = var.staging_dataset
  location    = var.bq_location
  description = "Silver: dbt staging models (parsed and typed)."
}

module "marts" {
  source = "../bigquery_datasets"

  project_id  = var.project_id
  dataset_id  = var.marts_dataset
  location    = var.bq_location
  description = "Gold: dbt marts (partitioned + clustered facts and dimensions)."
}
