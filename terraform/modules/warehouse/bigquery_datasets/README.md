# bigquery_datasets

Creates a **single BigQuery dataset**. Instantiate once per dataset
(bronze / silver / gold). Tables — and their partitioning/clustering — are
created later by the Pub/Sub BQ subscription (bronze) and by dbt (silver/gold),
not here.

## Usage

```hcl
module "bronze" {
  source = "./bigquery_datasets"

  project_id                  = var.project_id
  dataset_id                  = "bronze"
  location                    = var.bq_location
  description                 = "Bronze: raw match JSON landed by the Pub/Sub BQ subscription."
  default_table_expiration_ms = 30 * 24 * 60 * 60 * 1000 # 30 days
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
| project_id | GCP project ID that owns the dataset. | `string` | n/a | yes |
| dataset_id | BigQuery dataset ID (letters, numbers, underscores only). | `string` | n/a | yes |
| location | Dataset location, e.g. `"US"`. Must align with the pipeline region. | `string` | n/a | yes |
| description | Human-readable dataset description. | `string` | `""` | no |
| default_table_expiration_ms | Default table expiration in ms (`null` = never). | `number` | `null` | no |
| delete_contents_on_destroy | If true, `destroy` removes the dataset even if it holds tables. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| dataset_id | The dataset ID. |
| id | Fully-qualified dataset resource ID. |
| self_link | URI of the dataset resource. |
