# Single-root composition. Each module owns one former layer; cross-module values
# are passed directly (no terraform_remote_state). Every module depends on the
# project APIs enabled in apis.tf.

module "budget" {
  source = "../../modules/budget"

  project_id         = var.project_id
  billing_account    = var.billing_account
  budget_currency    = var.budget_currency
  budget_amount      = var.budget_amount
  threshold_percents = var.threshold_percents

  depends_on = [google_project_service.services]
}

module "cicd" {
  source = "../../modules/cicd"

  project_id        = var.project_id
  region            = var.region
  github_repository = var.github_repository
  artifact_repo_id  = var.artifact_repo_id

  depends_on = [google_project_service.services]
}

module "iam" {
  source = "../../modules/iam"

  project_id = var.project_id

  depends_on = [google_project_service.services]
}

module "warehouse" {
  source = "../../modules/warehouse"

  project_id     = var.project_id
  bq_location    = var.bq_location
  bronze_dataset = var.bronze_dataset
  silver_dataset = var.silver_dataset
  gold_dataset   = var.gold_dataset

  # Injected from iam (dataset-scoped role bindings live with the dataset).
  dbt_sa_email       = module.iam.dbt_sa_email
  pubsub_bq_sa_email = module.iam.pubsub_bq_sa_email

  depends_on = [google_project_service.services]
}

module "extraction" {
  source = "../../modules/extraction"

  project_id                       = var.project_id
  region                           = var.region
  topic_name                       = var.topic_name
  bronze_table_id                  = var.bronze_table_id
  bronze_partition_expiration_days = var.bronze_partition_expiration_days
  extractor_image_tag              = var.extractor_image_tag
  extractor_args                   = var.extractor_args
  riot_regional_host               = var.riot_regional_host
  riot_secret_id                   = var.riot_secret_id
  schedule_cron                    = var.schedule_cron
  schedule_time_zone               = var.schedule_time_zone

  # Injected from sibling modules.
  extractor_sa_email     = module.iam.extractor_sa_email
  scheduler_sa_email     = module.iam.scheduler_sa_email
  pubsub_bq_sa_email     = module.iam.pubsub_bq_sa_email
  bronze_dataset_id      = module.warehouse.bronze_dataset_id
  artifact_registry_repo = module.cicd.artifact_registry_repo

  depends_on = [google_project_service.services]
}

# The ingest module was renamed to extraction. Migrate the existing state
# subtree in place (no destroy/recreate).
moved {
  from = module.ingest
  to   = module.extraction
}
