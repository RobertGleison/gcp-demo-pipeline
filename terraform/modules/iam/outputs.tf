# SA emails are consumed directly by the warehouse and ingest modules via the
# root main.tf (no remote state). Resource-scoped role bindings are attached
# by those modules.

output "extractor_sa_email" {
  description = "Extractor runtime SA — granted pubsub.publisher + secretAccessor in the ingest layer."
  value       = module.extractor.email
}

output "dbt_sa_email" {
  description = "dbt runtime SA — granted bigquery.dataEditor in the warehouse layer."
  value       = module.dbt.email
}

output "scheduler_sa_email" {
  description = "Cloud Scheduler SA — granted run.jobs.run in the ingest / transform layers."
  value       = module.scheduler.email
}

output "pubsub_bq_sa_email" {
  description = "Pub/Sub->BQ subscription SA — granted bigquery.dataEditor on raw in the warehouse layer."
  value       = module.pubsub_bq.email
}
