# Riot API key secret. Created empty — no version is managed by Terraform; the
# key value is added by hand (Manual step #1) and refreshed ~daily for a dev key.
# The extractor reads it at run time via secret_env (RIOT_API_KEY), so the job
# spec never contains the key.
resource "google_secret_manager_secret" "riot_api_key" {
  project   = var.project_id
  secret_id = var.riot_secret_id

  replication {
    auto {}
  }

}

# Least privilege: only the extractor runtime SA can read the key, scoped to
# this secret (not project-wide secretAccessor).
resource "google_secret_manager_secret_iam_member" "extractor_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.riot_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.extractor_sa_email}"
}
