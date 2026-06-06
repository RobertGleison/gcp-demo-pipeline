variable "project_id" {
  description = "GCP project ID where the service account is created."
  type        = string
}

variable "account_id" {
  description = "Service account ID — the local part before the @ (e.g. \"sa-extractor\")."
  type        = string

  # GCP rule: 6-30 chars, start with a lowercase letter, end alphanumeric.
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.account_id))
    error_message = "account_id must be 6-30 chars: start with a lowercase letter, contain only lowercase letters/digits/hyphens, and end alphanumeric."
  }
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
