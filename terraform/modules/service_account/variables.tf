variable "project_id" {
  description = "GCP project ID where the service account is created."
  type        = string
}

variable "account_id" {
  description = "Service account ID — the local part before the @ (e.g. \"sa-extractor\")."
  type        = string
}

variable "display_name" {
  description = "Human-readable display name shown in the console."
  type        = string
}

variable "project_roles" {
  description = "Project-level IAM roles to grant this SA (e.g. [\"roles/bigquery.jobUser\"]). Resource-scoped roles are granted by the layer that owns the resource, not here."
  type        = list(string)
  default     = []
}
