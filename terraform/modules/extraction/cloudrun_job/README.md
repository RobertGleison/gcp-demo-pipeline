# cloudrun_job

A generic **Cloud Run v2 Job** plus an optional **Cloud Scheduler** trigger.
Reused by both pipeline workloads (extractor and dbt): same shape, different
image / env / schedule. The job scales to zero between runs.

The owning layer is responsible for pushing the image to Artifact Registry first,
granting the runtime SA its resource-scoped roles, and enabling
`run.googleapis.com` / `cloudscheduler.googleapis.com`.

## Usage

```hcl
module "extractor" {
  source = "./cloudrun_job"

  project_id            = var.project_id
  region                = var.region
  name                  = "extractor"
  image                 = local.extractor_image
  service_account_email = var.extractor_sa_email

  args = ["--count", "10"]

  env = {
    RIOT_REGIONAL_HOST = var.riot_regional_host
  }

  secret_env = {
    RIOT_API_KEY = { secret = "riot-api-key", version = "latest" }
  }

  scheduler_sa_email = var.scheduler_sa_email
  schedule           = "*/30 * * * *"
  time_zone          = "Etc/UTC"
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
| project_id | Project that owns the job and its scheduler trigger. | `string` | n/a | yes |
| region | Region for the job and scheduler (match the pipeline / BQ region). | `string` | n/a | yes |
| name | Base name for the job; the trigger is `<name>-trigger`. | `string` | n/a | yes |
| image | Full container image URI (pushed by CD before apply). | `string` | n/a | yes |
| service_account_email | Runtime identity the container runs as. | `string` | n/a | yes |
| command | Entrypoint override. Empty list keeps the image's ENTRYPOINT. | `list(string)` | `[]` | no |
| args | Container args. Empty list keeps the image's CMD. | `list(string)` | `[]` | no |
| env | Plain (non-secret) environment variables. | `map(string)` | `{}` | no |
| secret_env | Secret Manager-backed env vars: `name -> {secret, version}`. | `map(object({secret=string, version=optional(string,"latest")}))` | `{}` | no |
| cpu | CPU limit per task. | `string` | `"1"` | no |
| memory | Memory limit per task. | `string` | `"512Mi"` | no |
| max_retries | Task retries before the execution is marked failed. | `number` | `1` | no |
| task_timeout | Max run time for a single task (duration string). | `string` | `"600s"` | no |
| create_scheduler | Whether to create the Cloud Scheduler trigger. | `bool` | `true` | no |
| schedule | Unix-cron schedule (required when `create_scheduler`). | `string` | `null` | no |
| time_zone | IANA time zone for the cron schedule. | `string` | `"Etc/UTC"` | no |
| scheduler_sa_email | SA Cloud Scheduler authenticates as; granted the invoke role on this job. | `string` | `null` | no |
| invoke_role | IAM role granted to the scheduler SA on this job. | `string` | `"roles/run.invoker"` | no |
| scheduler_attempt_deadline | How long Scheduler waits for the `:run` call to be accepted. | `string` | `"320s"` | no |

## Outputs

| Name | Description |
|------|-------------|
| job_name | The Cloud Run Job name. |
| job_id | Fully-qualified Cloud Run Job resource ID. |
| scheduler_job_name | The Cloud Scheduler trigger name (`null` when `create_scheduler` is false). |
