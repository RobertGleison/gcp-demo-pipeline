# Root inputs for the prod environment.
# project_id and billing_account live in common.auto.tfvars (git-ignored) so the
# project/billing identifiers stay out of this public repo. Both files are
# auto-loaded by Terraform, so no -var-file flag is needed.
region            = "us-central1"
github_repository = "RobertGleison/gcp-demo-pipeline"

# Warehouse
bq_location    = "US"
bronze_dataset = "bronze"
silver_dataset = "silver"
gold_dataset   = "gold"

# Ingest
topic_name         = "lol-matches"
bronze_table_id    = "matches_bronze"
riot_regional_host = "https://americas.api.riotgames.com"
schedule_cron      = "*/30 * * * *"
