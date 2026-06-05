output "artifact_registry_repo" {
  description = "Image path prefix: <region>-docker.pkg.dev/<project>/<repo>."
  value       = module.cicd.artifact_registry_repo
}

output "wif_provider_name" {
  description = "Full WIF provider resource name — set as GitHub Actions var GCP_WIF_PROVIDER."
  value       = module.cicd.wif_provider_name
}

output "deployer_sa_email" {
  description = "Deployer SA email — set as GitHub Actions var GCP_DEPLOYER_SA."
  value       = module.cicd.deployer_sa_email
}

output "extractor_job_name" {
  description = "Extractor Cloud Run Job name."
  value       = module.ingest.extractor_job_name
}

output "topic_id" {
  description = "Main Pub/Sub topic the extractor publishes to."
  value       = module.ingest.topic_id
}
