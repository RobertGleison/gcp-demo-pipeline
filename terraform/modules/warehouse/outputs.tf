# Dataset IDs are consumed directly by the ingest module (raw subscription target)
# and the future transform module (dbt target datasets) via the root main.tf.

output "raw_dataset_id" {
  description = "Bronze landing dataset ID."
  value       = module.raw.dataset_id
}

output "staging_dataset_id" {
  description = "Silver dbt staging dataset ID."
  value       = module.staging.dataset_id
}

output "marts_dataset_id" {
  description = "Gold dbt marts dataset ID."
  value       = module.marts.dataset_id
}
