# iam

Mints the pipeline's **runtime service accounts** (one identity per workload) via
the `service_account` submodule and exports their emails. Only genuinely
project-wide roles (e.g. `bigquery.jobUser` for dbt) are granted here;
resource-scoped bindings live in the layer that owns the target resource:

| SA | Resource-scoped grants | Granted in |
|----|------------------------|------------|
| `sa-extractor` | `pubsub.publisher` (topic) + `secretAccessor` (Riot key) | extraction |
| `sa-dbt` | `bigquery.dataEditor` (datasets) | warehouse |
| `sa-scheduler` | `run.jobs.run` (each job) | extraction / transform |
| `sa-pubsub-bq` | `bigquery.dataEditor` (bronze) | warehouse |

The CD deployer SA (`sa-gh-deployer`) is **not** here — it lives in the cicd layer.

## Usage

```hcl
module "iam" {
  source = "../../modules/iam"

  project_id = var.project_id

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
| project_id | GCP project ID where the runtime SAs are created. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| extractor_sa_email | Extractor runtime SA email. |
| dbt_sa_email | dbt runtime SA email. |
| scheduler_sa_email | Cloud Scheduler SA email. |
| pubsub_bq_sa_email | Pub/Sub->BQ subscription writer SA email. |

## Submodules

- [`service_account`](../service_account) — instantiated four times, one per runtime identity.
