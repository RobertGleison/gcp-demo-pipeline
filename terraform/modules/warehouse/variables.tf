variable "project_id" {
  description = "GCP project ID that owns the datasets."
  type        = string
}

variable "bq_location" {
  description = "BigQuery dataset location (multi-region \"US\"). Must stay aligned with the pipeline region — a Pub/Sub BigQuery subscription cannot write across regions."
  type        = string
}

variable "raw_dataset" {
  description = "Dataset ID for the bronze landing zone (raw match JSON)."
  type        = string
  default     = "raw"
}

variable "staging_dataset" {
  description = "Dataset ID for silver dbt staging models."
  type        = string
  default     = "staging"
}

variable "marts_dataset" {
  description = "Dataset ID for gold dbt marts."
  type        = string
  default     = "marts"
}

variable "dbt_sa_email" {
  description = "dbt runtime SA email (from the iam module) — granted dataViewer on raw and dataEditor on staging/marts."
  type        = string
}

variable "pubsub_bq_sa_email" {
  description = "Pub/Sub->BQ subscription SA email (from the iam module) — granted dataEditor on raw."
  type        = string
}
