# A single BigQuery dataset. Instantiate once per dataset (bronze / silver / gold).
# Tables — and their partitioning/clustering — are created later by the Pub/Sub
# BQ subscription (bronze) and by dbt (silver/gold), not here.

resource "google_bigquery_dataset" "main" {
  project                    = var.project_id
  dataset_id                 = var.dataset_id
  location                   = var.location
  description                = var.description
  delete_contents_on_destroy = var.delete_contents_on_destroy

  # Optional dataset-wide default; e.g. bronze sets 30 days so the disposable
  # landing tables self-expire. null = tables never expire by default.
  default_table_expiration_ms = var.default_table_expiration_ms
}

# Renamed this -> main (HashiCorp style: a module's single resource is `main`).
moved {
  from = google_bigquery_dataset.this
  to   = google_bigquery_dataset.main
}
