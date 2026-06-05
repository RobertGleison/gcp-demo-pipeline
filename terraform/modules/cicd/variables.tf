variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Default region for regional resources (Artifact Registry lives here)."
  type        = string
}

variable "github_repository" {
  description = "GitHub repo allowed to push images via WIF, as owner/repo."
  type        = string
}

variable "artifact_repo_id" {
  description = "Artifact Registry repository ID (Docker format)."
  type        = string
  default     = "pipeline-images"
}
