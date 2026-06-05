variable "project_id" {
  description = "GCP project ID where the WIF pool and deployer SA are created."
  type        = string
}

variable "github_repository" {
  description = "GitHub repo allowed to impersonate the deployer SA, as owner/repo (e.g. RobertGleison/gcp-demo-pipeline)."
  type        = string
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
