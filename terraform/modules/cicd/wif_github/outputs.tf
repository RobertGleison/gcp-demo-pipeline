output "deployer_sa_email" {
  description = "Email of the GitHub Actions deployer service account."
  value       = google_service_account.deployer.email
}

output "pool_name" {
  description = "Full resource name of the Workload Identity Pool."
  value       = google_iam_workload_identity_pool.github.name
}

output "provider_name" {
  description = "Full resource name of the WIF provider (set as a GitHub Actions variable)."
  value       = google_iam_workload_identity_pool_provider.github.name
}
