variable "project_id" {
  description = "GCP project ID that owns the extraction resources."
  type        = string
}

variable "region" {
  description = "Pipeline region for Cloud Run, Scheduler, and Pub/Sub. Must align with the BQ location's region (a BigQuery subscription cannot write across regions)."
  type        = string
}

# --- Pub/Sub + landing -------------------------------------------------------

variable "topic_name" {
  description = "Main topic the extractor publishes matches to."
  type        = string
  default     = "lol-matches"
}

variable "bronze_table_id" {
  description = "Landing table in the bronze dataset that the BigQuery subscription writes to. Created by this layer (Pub/Sub does not auto-create it)."
  type        = string
  default     = "matches_bronze"
}

variable "bronze_partition_expiration_days" {
  description = "Days a daily partition of matches_bronze is kept before BigQuery drops it. bronze is disposable (replayable from Pub/Sub), so partitions self-expire."
  type        = number
  default     = 30
}

# --- Extractor job -----------------------------------------------------------

variable "extractor_image_tag" {
  description = "Tag of the extractor image in Artifact Registry to deploy (CD pushes <git-sha> + latest). The image must already exist before this layer applies."
  type        = string
  default     = "latest"
}

variable "extractor_args" {
  description = "Container args passed to the extractor each run, e.g. [\"--count\", \"10\"]."
  type        = list(string)
  default     = ["--count", "10"]
}

variable "riot_regional_host" {
  description = "Riot regional routing host for match-v5 / account-v1. americas = NA/BR/LAN/LAS; others europe / asia / sea."
  type        = string
  default     = "https://americas.api.riotgames.com"
}

variable "riot_secret_id" {
  description = "Secret Manager secret ID holding the Riot API key. Created empty here; the value is added by hand (Manual step #1) and refreshed ~daily for a dev key."
  type        = string
  default     = "riot-api-key"
}

# --- Schedule ----------------------------------------------------------------

variable "schedule_cron" {
  description = "Unix-cron schedule for the extractor trigger."
  type        = string
  default     = "*/30 * * * *"
}

variable "schedule_time_zone" {
  description = "IANA time zone the cron schedule is interpreted in."
  type        = string
  default     = "Etc/UTC"
}

# --- Injected from sibling modules (wired in the root main.tf) ----------------

variable "extractor_sa_email" {
  description = "Extractor runtime SA email (from the iam module)."
  type        = string
}

variable "scheduler_sa_email" {
  description = "Cloud Scheduler SA email (from the iam module)."
  type        = string
}

variable "pubsub_bq_sa_email" {
  description = "Pub/Sub->BQ subscription writer SA email (from the iam module)."
  type        = string
}

variable "bronze_dataset_id" {
  description = "bronze landing dataset ID (from the warehouse module)."
  type        = string
}

variable "artifact_registry_repo" {
  description = "Artifact Registry image path prefix (from the cicd module)."
  type        = string
}
