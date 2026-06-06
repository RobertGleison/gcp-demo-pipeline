variable "project_id" {
  description = "GCP project ID that owns the datasets."
  type        = string
}

variable "bq_location" {
  description = "BigQuery dataset location (multi-region \"US\"). Must stay aligned with the pipeline region — a Pub/Sub BigQuery subscription cannot write across regions."
  type        = string
}

variable "bronze_dataset" {
  description = "Dataset ID for the bronze landing zone (bronze match JSON)."
  type        = string
  default     = "bronze"
}

variable "silver_dataset" {
  description = "Dataset ID for silver dbt silver models."
  type        = string
  default     = "silver"
}

variable "gold_dataset" {
  description = "Dataset ID for gold dbt gold."
  type        = string
  default     = "gold"
}

variable "dbt_sa_email" {
  description = "dbt runtime SA email (from the iam module) — granted dataViewer on bronze and dataEditor on silver/gold."
  type        = string
}

variable "pubsub_bq_sa_email" {
  description = "Pub/Sub->BQ subscription SA email (from the iam module) — granted dataEditor on bronze."
  type        = string
}
