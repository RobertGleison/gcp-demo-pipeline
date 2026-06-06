# --- Project-wide -------------------------------------------------------------
variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Default region for regional resources (Cloud Run, Scheduler, Pub/Sub, Artifact Registry)."
  type        = string
}

# --- Budget -------------------------------------------------------------------
variable "billing_account" {
  description = "Billing account ID that funds the project."
  type        = string
}

variable "budget_currency" {
  description = "Currency for the budget amount; must match the billing account's currency."
  type        = string
  default     = "EUR"
}

variable "budget_amount" {
  description = "Budget baseline in budget_currency."
  type        = number
  default     = 200
}

variable "threshold_percents" {
  description = "Fractions of budget_amount at which to alert."
  type        = list(number)
  default     = [0.25, 0.5, 1.0]
}

# --- CI/CD --------------------------------------------------------------------
variable "github_repository" {
  description = "GitHub repo allowed to push images via WIF, as owner/repo."
  type        = string
}

variable "artifact_repo_id" {
  description = "Artifact Registry repository ID (Docker format)."
  type        = string
  default     = "pipeline-images"
}

# --- Warehouse ----------------------------------------------------------------
variable "bq_location" {
  description = "BigQuery dataset location (e.g. multi-region \"US\")."
  type        = string
}

variable "bronze_dataset" {
  description = "Dataset ID for the bronze landing zone."
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

# --- Ingest -------------------------------------------------------------------
variable "topic_name" {
  description = "Main topic the extractor publishes matches to."
  type        = string
  default     = "lol-matches"
}

variable "bronze_table_id" {
  description = "Landing table in the bronze dataset the BigQuery subscription writes to."
  type        = string
  default     = "matches_bronze"
}

variable "bronze_partition_expiration_days" {
  description = "Days a daily partition of matches_bronze is kept before BigQuery drops it."
  type        = number
  default     = 30
}

variable "extractor_image_tag" {
  description = "Tag of the extractor image in Artifact Registry to deploy."
  type        = string
  default     = "latest"
}

variable "extractor_args" {
  description = "Container args passed to the extractor each run."
  type        = list(string)
  default     = ["--count", "10"]
}

variable "riot_regional_host" {
  description = "Riot regional routing host for match-v5 / account-v1."
  type        = string
  default     = "https://americas.api.riotgames.com"
}

variable "riot_secret_id" {
  description = "Secret Manager secret ID holding the Riot API key (value added by hand)."
  type        = string
  default     = "riot-api-key"
}

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
