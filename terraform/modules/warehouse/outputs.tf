# Dataset IDs are consumed directly by the ingest module (bronze subscription target)
# and the future transform module (dbt target datasets) via the root main.tf.

output "bronze_dataset_id" {
  description = "Bronze landing dataset ID."
  value       = module.bronze.dataset_id
}

output "silver_dataset_id" {
  description = "Silver dbt silver dataset ID."
  value       = module.silver.dataset_id
}

output "gold_dataset_id" {
  description = "Gold dbt gold dataset ID."
  value       = module.gold.dataset_id
}
