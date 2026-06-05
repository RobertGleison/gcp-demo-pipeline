# These three values are the hand-off to GitHub Actions (Manual step #2 in the
# design doc). Set them as repo variables; no JSON key is ever produced.

output "artifact_registry_repo" {
  description = "Image path prefix: <region>-docker.pkg.dev/<project>/<repo>."
  value       = "${google_artifact_registry_repository.images.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

output "wif_provider_name" {
  description = "Full WIF provider resource name — set as GitHub Actions var GCP_WIF_PROVIDER."
  value       = module.wif_github.provider_name
}

output "deployer_sa_email" {
  description = "Deployer SA email — set as GitHub Actions var GCP_DEPLOYER_SA."
  value       = module.wif_github.deployer_sa_email
}
