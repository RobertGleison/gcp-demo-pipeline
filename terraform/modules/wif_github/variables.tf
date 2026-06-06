variable "project_id" {
  description = "GCP project ID where the WIF pool and deployer SA are created."
  type        = string
}

variable "github_repository" {
  description = "GitHub repo allowed to impersonate the deployer SA, as owner/repo (e.g. RobertGleison/gcp-demo-pipeline)."
  type        = string

  # This value becomes the provider's attribute_condition (the security gate on
  # who may mint deployer-SA tokens), so a malformed value must fail fast.
  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must be in \"owner/repo\" form (exactly one slash)."
  }
}

variable "pool_id" {
  description = "Workload Identity Pool ID."
  type        = string
  default     = "github-pool"
}

variable "provider_id" {
  description = "Workload Identity Pool Provider ID."
  type        = string
  default     = "github-provider"
}

variable "deployer_account_id" {
  description = "Account ID (local part) of the GitHub Actions deployer service account."
  type        = string
  default     = "sa-gh-deployer"
}
