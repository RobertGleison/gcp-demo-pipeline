# The extractor Cloud Run Job + its Cloud Scheduler trigger (the generic
# cloudrun_job module). Runs as sa-extractor; reads the Riot key from Secret
# Manager and publishes to the Pub/Sub topic above.
module "extractor" {
  source = "../cloudrun_job"

  project_id            = var.project_id
  region                = var.region
  name                  = "extractor"
  image                 = local.extractor_image
  service_account_email = var.extractor_sa_email

  args = var.extractor_args

  env = {
    RIOT_REGIONAL_HOST = var.riot_regional_host
    # Full topic path (projects/<p>/topics/<name>) — what the producer publishes to.
    PUBSUB_TOPIC = module.pubsub.topic_id
  }

  secret_env = {
    RIOT_API_KEY = {
      secret  = google_secret_manager_secret.riot_api_key.secret_id
      version = "latest"
    }
  }

  scheduler_sa_email = var.scheduler_sa_email
  schedule           = var.schedule_cron
  time_zone          = var.schedule_time_zone

}
