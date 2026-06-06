# warehouse

The three **medallion datasets** (bronze / silver / gold) via the
`bigquery_datasets` submodule, plus the dataset-scoped IAM grants deferred from
the iam layer (bindings live with the resource they apply to). bronze tables
self-expire after 30 days (disposable — replayable from Pub/Sub).

| Grant | Member | Dataset |
|-------|--------|---------|
| `bigquery.dataEditor` | `sa-pubsub-bq` | bronze |
| `bigquery.dataViewer` | `sa-dbt` | bronze |
| `bigquery.dataEditor` | `sa-dbt` | silver, gold |

## Usage

```hcl
module "warehouse" {
  source = "../../modules/warehouse"

  project_id  = var.project_id
  bq_location = var.bq_location

  dbt_sa_email       = module.iam.dbt_sa_email
  pubsub_bq_sa_email = module.iam.pubsub_bq_sa_email

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
| project_id | GCP project ID that owns the datasets. | `string` | n/a | yes |
| bq_location | BigQuery dataset location (e.g. multi-region `"US"`). | `string` | n/a | yes |
| bronze_dataset | Dataset ID for the bronze landing zone. | `string` | `"bronze"` | no |
| silver_dataset | Dataset ID for silver dbt models. | `string` | `"silver"` | no |
| gold_dataset | Dataset ID for gold dbt models. | `string` | `"gold"` | no |
| dbt_sa_email | dbt runtime SA email (from the iam layer). | `string` | n/a | yes |
| pubsub_bq_sa_email | Pub/Sub->BQ subscription SA email (from the iam layer). | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| bronze_dataset_id | Bronze landing dataset ID. |
| silver_dataset_id | Silver dataset ID. |
| gold_dataset_id | Gold dataset ID. |

## Submodules

- [`bigquery_datasets`](../bigquery_datasets) — instantiated three times (bronze / silver / gold).
