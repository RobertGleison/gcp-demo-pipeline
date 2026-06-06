# The three medallion datasets. Table-level partitioning/clustering is set by
# the writers (Pub/Sub BQ subscription for bronze, dbt for silver/gold).
locals {
  # bronze is disposable — it's the replayable source of truth landed from Pub/Sub,
  # so its tables self-expire after 30 days.
  bronze_table_expiration_ms = 30 * 24 * 60 * 60 * 1000
}

module "bronze" {
  source = "./bigquery_datasets"

  project_id                  = var.project_id
  dataset_id                  = var.bronze_dataset
  location                    = var.bq_location
  description                 = "Bronze: bronze match JSON landed by the Pub/Sub BigQuery subscription."
  default_table_expiration_ms = local.bronze_table_expiration_ms
}

module "silver" {
  source = "./bigquery_datasets"

  project_id  = var.project_id
  dataset_id  = var.silver_dataset
  location    = var.bq_location
  description = "Silver: dbt silver models (parsed and typed)."
}

module "gold" {
  source = "./bigquery_datasets"

  project_id  = var.project_id
  dataset_id  = var.gold_dataset
  location    = var.bq_location
  description = "Gold: dbt gold (partitioned + clustered facts and dimensions)."
}
