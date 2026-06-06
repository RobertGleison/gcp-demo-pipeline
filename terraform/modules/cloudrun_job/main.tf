# A generic Cloud Run v2 Job plus an optional Cloud Scheduler trigger.
# Reused by both pipeline workloads (extractor and dbt): same shape, different
# image / env / schedule. The job scales to zero between runs — cost is only the
# seconds it actually executes.
#
# The owning layer is responsible for:
#   - pushing the image to Artifact Registry first (via CD),
#   - granting the runtime SA its resource-scoped roles (pubsub.publisher,
#     secretAccessor, BigQuery), and
#   - enabling run.googleapis.com / cloudscheduler.googleapis.com (apis.tf).

resource "google_cloud_run_v2_job" "main" {
  name     = var.name
  location = var.region
  project  = var.project_id

  # Study project — let `terraform destroy` remove the job cleanly.
  deletion_protection = false

  template {
    template {
      service_account = var.service_account_email
      max_retries     = var.max_retries
      timeout         = var.task_timeout

      containers {
        image = var.image

        # null (not []) so an empty list keeps the image's own ENTRYPOINT/CMD
        # instead of overriding them to nothing.
        command = length(var.command) > 0 ? var.command : null
        args    = length(var.args) > 0 ? var.args : null

        # Plain env vars.
        dynamic "env" {
          for_each = var.env
          content {
            name  = env.key
            value = env.value
          }
        }

        # Secret Manager-backed env vars (e.g. the Riot API key). The value is
        # resolved at run time from Secret Manager — never stored in the job spec.
        dynamic "env" {
          for_each = var.secret_env
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value.secret
                version = env.value.version
              }
            }
          }
        }

        resources {
          limits = {
            cpu    = var.cpu
            memory = var.memory
          }
        }
      }
    }
  }
}

# Renamed this -> main (HashiCorp style: a module's single resource is `main`).
moved {
  from = google_cloud_run_v2_job.this
  to   = google_cloud_run_v2_job.main
}

# Cloud Scheduler triggers the job by POSTing to the Run Admin API's :run
# endpoint, authenticating as sa-scheduler. Jobs need run.jobs.run (contained in
# roles/run.invoker); scoped to this job only — least privilege.
resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  count = var.create_scheduler ? 1 : 0

  project  = var.project_id
  location = google_cloud_run_v2_job.main.location
  name     = google_cloud_run_v2_job.main.name
  role     = var.invoke_role
  member   = "serviceAccount:${var.scheduler_sa_email}"
}

resource "google_cloud_scheduler_job" "trigger" {
  count = var.create_scheduler ? 1 : 0

  project     = var.project_id
  region      = var.region
  name        = "${var.name}-trigger"
  description = "Runs the ${var.name} Cloud Run Job on a schedule."
  schedule    = var.schedule
  time_zone   = var.time_zone

  # Bounds only the :run call (the job runs asynchronously after it's accepted).
  attempt_deadline = var.scheduler_attempt_deadline

  http_target {
    http_method = "POST"
    # v1 namespaces endpoint is the one Cloud Scheduler authenticates against for
    # jobs:run. oauth_token (not oidc) because the audience is a *.googleapis.com
    # Google API.
    uri = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.main.name}:run"

    oauth_token {
      service_account_email = var.scheduler_sa_email
    }
  }

  # Don't let the scheduler exist before the SA can actually invoke the job.
  depends_on = [google_cloud_run_v2_job_iam_member.scheduler_invoker]
}
