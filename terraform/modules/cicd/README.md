# cicd

The CI/CD layer: a single **Artifact Registry** Docker repo for the pipeline
images (extractor + dbt) and **keyless GitHub Actions auth** via the `wif_github`
submodule. The deployer SA can push to this repo only (least privilege). Its
three outputs are the hand-off to GitHub Actions repo variables — no JSON key is
ever produced.

## Usage

```hcl
module "cicd" {
  source = "../../modules/cicd"

  project_id        = var.project_id
  region            = var.region
  github_repository = var.github_repository
  artifact_repo_id  = "pipeline-images"

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
| project_id | GCP project ID. | `string` | n/a | yes |
| region | Default region for regional resources (Artifact Registry lives here). | `string` | n/a | yes |
| github_repository | Repo allowed to push images via WIF, as `owner/repo`. | `string` | n/a | yes |
| artifact_repo_id | Artifact Registry repository ID (Docker format). | `string` | `"pipeline-images"` | no |

## Outputs

| Name | Description |
|------|-------------|
| artifact_registry_repo | Image path prefix `<region>-docker.pkg.dev/<project>/<repo>`. |
| wif_provider_name | Full WIF provider resource name (GitHub Actions var `GCP_WIF_PROVIDER`). |
| deployer_sa_email | Deployer SA email (GitHub Actions var `GCP_DEPLOYER_SA`). |

## Submodules

- [`wif_github`](../wif_github) — Workload Identity Federation pool, provider, and deployer SA.
