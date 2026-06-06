output "job_name" {
  description = "The Cloud Run Job name."
  value       = google_cloud_run_v2_job.main.name
}

output "job_id" {
  description = "Fully-qualified Cloud Run Job resource ID."
  value       = google_cloud_run_v2_job.main.id
}

output "scheduler_job_name" {
  description = "The Cloud Scheduler trigger name (null when create_scheduler is false)."
  value       = var.create_scheduler ? google_cloud_scheduler_job.trigger[0].name : null
}
