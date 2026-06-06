# service_account

Creates a single service account plus any **project-level** IAM role bindings.
Resource-scoped grants (a role on one topic / dataset / job) deliberately live in
the layer that owns that resource — this module handles only the identity and
genuinely project-wide roles.

## Usage

```hcl
module "dbt" {
  source = "./service_account"

  project_id   = var.project_id
  account_id   = "sa-dbt"
  display_name = "dbt Cloud Run Job runtime"

  # Project-scoped roles only; dataset-scoped grants live in the warehouse layer.
  project_roles = ["roles/bigquery.jobUser"]
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
| project_id | GCP project ID where the service account is created. | `string` | n/a | yes |
| account_id | SA ID (local part before the @, e.g. `sa-extractor`). Validated: 6-30 chars, lowercase. | `string` | n/a | yes |
| display_name | Human-readable display name shown in the console. | `string` | n/a | yes |
| project_roles | Project-level IAM roles to grant this SA. Resource-scoped roles go in the owning layer. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| email | Service account email. |
| member | IAM member string (`serviceAccount:<email>`) for role bindings. |
| name | Resource name (`projects/<project>/serviceAccounts/<email>`). |
