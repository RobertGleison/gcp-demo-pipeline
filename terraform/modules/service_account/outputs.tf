output "email" {
  description = "Service account email."
  value       = google_service_account.this.email
}

output "member" {
  description = "IAM member string (serviceAccount:<email>) for use in role bindings."
  value       = "serviceAccount:${google_service_account.this.email}"
}

output "name" {
  description = "Service account resource name (projects/<project>/serviceAccounts/<email>)."
  value       = google_service_account.this.name
}
