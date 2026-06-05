output "dataset_id" {
  description = "The dataset ID."
  value       = google_bigquery_dataset.this.dataset_id
}

output "id" {
  description = "Fully-qualified dataset resource ID (projects/<project>/datasets/<id>)."
  value       = google_bigquery_dataset.this.id
}

output "self_link" {
  description = "URI of the dataset resource."
  value       = google_bigquery_dataset.this.self_link
}
