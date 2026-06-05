output "topic_id" {
  description = "Main topic the extractor publishes to (projects/<project>/topics/<name>)."
  value       = module.pubsub.topic_id
}

output "subscription_name" {
  description = "BigQuery subscription landing matches into raw.matches_raw."
  value       = module.pubsub.subscription_name
}

output "dlq_subscription_name" {
  description = "DLQ pull subscription for inspecting dead-lettered messages."
  value       = module.pubsub.dlq_subscription_name
}

output "matches_raw_table" {
  description = "Fully-qualified landing table ID."
  value       = "${var.project_id}.${var.raw_dataset_id}.${google_bigquery_table.matches_raw.table_id}"
}

output "extractor_job_name" {
  description = "Extractor Cloud Run Job name."
  value       = module.extractor.job_name
}

output "riot_secret_id" {
  description = "Secret Manager secret ID for the Riot API key (add the value by hand)."
  value       = google_secret_manager_secret.riot_api_key.secret_id
}
