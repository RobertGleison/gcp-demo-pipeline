# Root inputs for the prod environment.
# project_id and billing_account live in common.auto.tfvars (git-ignored) so the
# project/billing identifiers stay out of this public repo. Both files are
# auto-loaded by Terraform, so no -var-file flag is needed.
region            = "us-central1"
github_repository = "RobertGleison/gcp-demo-pipeline"

# Warehouse
bq_location     = "US"
raw_dataset     = "raw"
staging_dataset = "staging"
marts_dataset   = "marts"

# Ingest
topic_name         = "lol-matches"
raw_table_id       = "matches_raw"
riot_regional_host = "https://americas.api.riotgames.com"
schedule_cron      = "*/30 * * * *"
