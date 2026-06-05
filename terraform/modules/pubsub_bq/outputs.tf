output "topic_id" {
  description = "Fully-qualified main topic ID (projects/<project>/topics/<name>) — what sa-extractor publishes to."
  value       = google_pubsub_topic.main.id
}

output "topic_name" {
  description = "Main topic short name."
  value       = google_pubsub_topic.main.name
}

output "dlq_topic_id" {
  description = "Dead-letter topic ID."
  value       = google_pubsub_topic.dlq.id
}

output "subscription_name" {
  description = "BigQuery subscription name."
  value       = google_pubsub_subscription.bq.name
}

output "dlq_subscription_name" {
  description = "DLQ pull subscription name (manual inspection)."
  value       = google_pubsub_subscription.dlq.name
}
