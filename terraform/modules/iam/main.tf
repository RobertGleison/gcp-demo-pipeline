# Runtime service accounts for the pipeline (one identity per workload).
# Each SA is created here and its email is exported; the resource-scoped role
# bindings are granted by the layer that owns the target resource:
#   - sa-extractor : pubsub.publisher (topic) + secretAccessor (Riot key)  -> extraction
#   - sa-dbt       : bigquery.dataEditor (datasets)                        -> warehouse
#   - sa-scheduler : run.jobs.run (each job)                               -> extraction / transform
#   - sa-pubsub-bq : bigquery.dataEditor (bronze dataset)                     -> warehouse
# Only genuinely project-wide roles (e.g. bigquery.jobUser) are granted here.
#
# The CD deployer SA (sa-gh-deployer) is NOT here — it lives in the cicd layer.

module "extractor" {
  source = "./service_account"

  project_id   = var.project_id
  account_id   = "sa-extractor"
  display_name = "Extractor Cloud Run Job runtime"
}

module "dbt" {
  source = "./service_account"

  project_id   = var.project_id
  account_id   = "sa-dbt"
  display_name = "dbt Cloud Run Job runtime"

  # jobUser is project-scoped (run query jobs); dataEditor (dataset-scoped) is
  # granted in the warehouse layer.
  project_roles = ["roles/bigquery.jobUser"]
}

module "scheduler" {
  source = "./service_account"

  project_id   = var.project_id
  account_id   = "sa-scheduler"
  display_name = "Cloud Scheduler job trigger"
}

module "pubsub_bq" {
  source = "./service_account"

  project_id   = var.project_id
  account_id   = "sa-pubsub-bq"
  display_name = "Pub/Sub -> BigQuery subscription writer"
}
