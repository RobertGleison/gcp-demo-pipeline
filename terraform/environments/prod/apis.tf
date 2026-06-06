# Every API the project needs, enabled once. In a single state, two
# google_project_service resources for the same API would collide — so the
# previously per-layer lists are merged and deduplicated here. Modules depend on
# this via depends_on in main.tf.
locals {
  project_apis = [
    "billingbudgets.googleapis.com",       # budget
    "cloudbilling.googleapis.com",         # budget
    "artifactregistry.googleapis.com",     # cicd
    "iam.googleapis.com",                  # cicd + iam
    "iamcredentials.googleapis.com",       # cicd (WIF)
    "sts.googleapis.com",                  # cicd (WIF)
    "cloudresourcemanager.googleapis.com", # cicd + iam
    "run.googleapis.com",                  # extraction
    "cloudscheduler.googleapis.com",       # extraction
    "pubsub.googleapis.com",               # extraction
    "secretmanager.googleapis.com",        # extraction
    "bigquery.googleapis.com",             # warehouse + extraction
  ]
}

resource "google_project_service" "services" {
  for_each = toset(local.project_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
