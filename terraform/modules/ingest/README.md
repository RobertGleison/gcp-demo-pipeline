# ingest

The ingest layer wires the extractor to the warehouse:

- the **landing table** `matches_bronze` (Pub/Sub does not auto-create it),
- a **topic + DLQ + BigQuery subscription** (via the `pubsub_bq` submodule),
- the **extractor Cloud Run Job + Scheduler trigger** (via the `cloudrun_job` submodule),
- the **Riot API key secret** (created empty; value added by hand), and
- the least-privilege bindings the workload SAs need (publisher on the topic,
  secretAccessor on the key).

## Usage

```hcl
module "ingest" {
  source = "../../modules/ingest"

  project_id      = var.project_id
  region          = var.region
  topic_name      = "lol-matches"
  bronze_table_id = "matches_bronze"

  extractor_sa_email     = module.iam.extractor_sa_email
  scheduler_sa_email     = module.iam.scheduler_sa_email
  pubsub_bq_sa_email     = module.iam.pubsub_bq_sa_email
  bronze_dataset_id      = module.warehouse.bronze_dataset_id
  artifact_registry_repo = module.cicd.artifact_registry_repo

  depends_on = [google_project_service.services]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| google | ~> 6.0 (inherited from the root) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | Project that owns the ingest resources. | `string` | n/a | yes |
| region | Pipeline region (must align with the BQ location's region). | `string` | n/a | yes |
| topic_name | Main topic the extractor publishes to. | `string` | `"lol-matches"` | no |
| bronze_table_id | Landing table in the bronze dataset. | `string` | `"matches_bronze"` | no |
| bronze_partition_expiration_days | Days a daily partition of the landing table is kept. | `number` | `30` | no |
| extractor_image_tag | Tag of the extractor image to deploy. | `string` | `"latest"` | no |
| extractor_args | Container args passed to the extractor each run. | `list(string)` | `["--count","10"]` | no |
| riot_regional_host | Riot regional routing host. | `string` | `"https://americas.api.riotgames.com"` | no |
| riot_secret_id | Secret Manager secret ID for the Riot API key. | `string` | `"riot-api-key"` | no |
| schedule_cron | Unix-cron schedule for the extractor trigger. | `string` | `"*/30 * * * *"` | no |
| schedule_time_zone | IANA time zone for the schedule. | `string` | `"Etc/UTC"` | no |
| extractor_sa_email | Extractor runtime SA email (from the iam layer). | `string` | n/a | yes |
| scheduler_sa_email | Cloud Scheduler SA email (from the iam layer). | `string` | n/a | yes |
| pubsub_bq_sa_email | Pub/Sub->BQ subscription writer SA email (from the iam layer). | `string` | n/a | yes |
| bronze_dataset_id | Bronze landing dataset ID (from the warehouse layer). | `string` | n/a | yes |
| artifact_registry_repo | Artifact Registry image path prefix (from the cicd layer). | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| topic_id | Main topic the extractor publishes to. |
| subscription_name | BigQuery subscription landing matches into bronze. |
| dlq_subscription_name | DLQ pull subscription for inspecting dead-lettered messages. |
| matches_bronze_table | Fully-qualified landing table ID. |
| extractor_job_name | Extractor Cloud Run Job name. |
| riot_secret_id | Secret Manager secret ID for the Riot API key. |

## Submodules

- [`pubsub_bq`](../pubsub_bq) — topic, DLQ, and BigQuery subscription.
- [`cloudrun_job`](../cloudrun_job) — extractor job and its scheduler trigger.
