provider "google" {
  project = var.project_id
  region  = var.region

  # Send an X-Goog-User-Project header so APIs that demand a quota/billing
  # project under user ADC (e.g. billingbudgets) work without per-user setup.
  billing_project       = var.project_id
  user_project_override = true
}
