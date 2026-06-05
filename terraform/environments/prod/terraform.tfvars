# Root inputs for the prod environment.
project_id        = "project-5a3b1a75-500c-4b93-9e1"
region            = "us-central1"
github_repository = "RobertGleison/gcp-demo-pipeline"
billing_account   = "016260-E54BF6-671DF7"

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
