variable "project_id" {
  description = "GCP project ID that owns the job and its scheduler trigger."
  type        = string
}

variable "region" {
  description = "Region for the Cloud Run Job and the Cloud Scheduler job. Must match the pipeline region (and the BQ location's region for cross-service writes)."
  type        = string
}

variable "name" {
  description = "Base name for the job. The scheduler trigger is named \"<name>-trigger\"."
  type        = string
}

variable "image" {
  description = "Full container image URI, e.g. <region>-docker.pkg.dev/<project>/<repo>/extractor:<sha>. Pushed by CD before this layer applies."
  type        = string
}

variable "service_account_email" {
  description = "Runtime identity the job's container runs as (e.g. sa-extractor / sa-dbt). Resource-scoped grants (pubsub.publisher, secretAccessor, BQ) live in the owning layer."
  type        = string
}

variable "command" {
  description = "Container entrypoint override. Empty list keeps the image's ENTRYPOINT."
  type        = list(string)
  default     = []
}

variable "args" {
  description = "Container args, e.g. [\"--count\", \"10\"]. Empty list keeps the image's CMD."
  type        = list(string)
  default     = []
}

variable "env" {
  description = "Plain (non-secret) environment variables for the container."
  type        = map(string)
  default     = {}
}

variable "secret_env" {
  description = "Secret Manager-backed env vars: env var name -> {secret = <secret id>, version = <version|\"latest\">}. The runtime SA needs secretAccessor on each secret (granted in the owning layer)."
  type = map(object({
    secret  = string
    version = optional(string, "latest")
  }))
  default = {}
}

variable "cpu" {
  description = "CPU limit per task (e.g. \"1\", \"2\")."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory limit per task (e.g. \"512Mi\", \"1Gi\")."
  type        = string
  default     = "512Mi"
}

variable "max_retries" {
  description = "Times a failed task is retried before the execution is marked failed."
  type        = number
  default     = 1
}

variable "task_timeout" {
  description = "Maximum run time for a single task, as a duration string (e.g. \"600s\")."
  type        = string
  default     = "600s"
}

# --- Scheduler trigger -------------------------------------------------------

variable "create_scheduler" {
  description = "Whether to create a Cloud Scheduler job that triggers this Cloud Run Job. Set false for manually-run jobs."
  type        = bool
  default     = true
}

variable "schedule" {
  description = "Unix-cron schedule for the trigger (e.g. \"*/30 * * * *\"). Required when create_scheduler is true."
  type        = string
  default     = null
}

variable "time_zone" {
  description = "IANA time zone the cron schedule is interpreted in."
  type        = string
  default     = "Etc/UTC"
}

variable "scheduler_sa_email" {
  description = "Service account Cloud Scheduler authenticates as when calling the Run Admin API (sa-scheduler). Granted the invoke role on this job by the module."
  type        = string
  default     = null
}

variable "invoke_role" {
  description = "IAM role granted to scheduler_sa_email on this job so it can run it. roles/run.invoker now includes run.jobs.run (the design doc's note that it's \"Services only\" predates that change)."
  type        = string
  default     = "roles/run.invoker"
}

variable "scheduler_attempt_deadline" {
  description = "How long Cloud Scheduler waits for the :run call to be accepted before treating the attempt as failed. The job itself runs async, so this only bounds the trigger call."
  type        = string
  default     = "320s"
}
