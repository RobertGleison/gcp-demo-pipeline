# A single service account plus any project-level role bindings.
# Resource-scoped grants (a role on one topic / dataset / job) live in the
# layer that owns that resource — this module handles only the identity and
# any genuinely project-wide roles.

resource "google_service_account" "main" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = var.display_name
}

resource "google_project_iam_member" "roles" {
  for_each = toset(var.project_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.main.email}"
}

# Renamed this -> main (HashiCorp style: a module's single resource is `main`).
moved {
  from = google_service_account.this
  to   = google_service_account.main
}
