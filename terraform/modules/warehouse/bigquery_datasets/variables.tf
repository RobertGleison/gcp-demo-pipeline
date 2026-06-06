variable "project_id" {
  description = "GCP project ID that owns the dataset."
  type        = string
}

variable "dataset_id" {
  description = "BigQuery dataset ID (letters, numbers, and underscores only)."
  type        = string
}

variable "location" {
  description = "Dataset location, e.g. \"US\" multi-region. Must align with the pipeline region."
  type        = string
}

variable "description" {
  description = "Human-readable dataset description."
  type        = string
  default     = ""
}

variable "default_table_expiration_ms" {
  description = "Default expiration for tables in this dataset, in milliseconds (null = tables never expire by default)."
  type        = number
  default     = null
}

variable "delete_contents_on_destroy" {
  description = "If true, `terraform destroy` removes the dataset even if it still contains tables."
  type        = bool
  default     = false
}
