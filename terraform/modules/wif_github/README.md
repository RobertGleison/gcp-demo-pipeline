# wif_github

**Workload Identity Federation** for keyless GitHub Actions auth. GitHub's OIDC
token is exchanged for short-lived GCP credentials that impersonate the deployer
SA — no service-account JSON keys anywhere. Only OIDC tokens minted for the exact
configured repo may use the provider (`attribute_condition`).

## Usage

```hcl
module "wif_github" {
  source = "../wif_github"

  project_id        = var.project_id
  github_repository = "RobertGleison/gcp-demo-pipeline"
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
| project_id | Project where the WIF pool and deployer SA are created. | `string` | n/a | yes |
| github_repository | Repo allowed to impersonate the deployer SA, as `owner/repo`. Validated. | `string` | n/a | yes |
| pool_id | Workload Identity Pool ID. | `string` | `"github-pool"` | no |
| provider_id | Workload Identity Pool Provider ID. | `string` | `"github-provider"` | no |
| deployer_account_id | Account ID (local part) of the deployer SA. | `string` | `"sa-gh-deployer"` | no |

## Outputs

| Name | Description |
|------|-------------|
| deployer_sa_email | Email of the GitHub Actions deployer SA. |
| pool_name | Full resource name of the Workload Identity Pool. |
| provider_name | Full resource name of the WIF provider. |
