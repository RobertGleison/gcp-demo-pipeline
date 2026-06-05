# Single Docker repo hosting both images (extractor + dbt), pushed by CD.
resource "google_artifact_registry_repository" "images" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_repo_id
  format        = "DOCKER"
  description   = "Container images for the LoL pipeline (extractor + dbt), pushed by GitHub Actions CD."

}

# Least privilege: the deployer SA can push to this repo only.
resource "google_artifact_registry_repository_iam_member" "deployer_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.images.location
  repository = google_artifact_registry_repository.images.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${module.wif_github.deployer_sa_email}"
}
