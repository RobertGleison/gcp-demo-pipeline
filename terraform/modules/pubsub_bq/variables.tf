variable "project_id" {
  description = "GCP project ID that owns the topics and subscriptions."
  type        = string
}

variable "topic_name" {
  description = "Name of the main topic the extractor publishes matches to."
  type        = string
}

variable "dlq_topic_name" {
  description = "Dead-letter topic name. Defaults to \"<topic_name>-dlq\"."
  type        = string
  default     = null
}

variable "subscription_name" {
  description = "BigQuery subscription name. Defaults to \"<topic_name>-bq\"."
  type        = string
  default     = null
}

variable "dlq_subscription_name" {
  description = "Pull subscription on the DLQ (no consumer — just bounds retention so failed messages can be inspected). Defaults to \"<dlq_topic_name>-pull\"."
  type        = string
  default     = null
}

# --- BigQuery write target ---------------------------------------------------

variable "bq_dataset_id" {
  description = "Dataset holding the landing table (the bronze/bronze dataset)."
  type        = string
}

variable "bq_table_id" {
  description = "Existing table the subscription writes to. Pub/Sub does NOT create it — the owning layer must create it first with the metadata schema."
  type        = string
  default     = "matches_bronze"
}

variable "writer_sa_email" {
  description = "Service account the BigQuery subscription writes as (sa-pubsub-bq). It needs bigquery.dataEditor on the dataset (granted in the warehouse layer); the module grants the Pub/Sub service agent tokenCreator on it. If null, Pub/Sub's own service agent writes instead."
  type        = string
  default     = null
}

variable "write_metadata" {
  description = "Write Pub/Sub metadata columns (subscription_name, message_id, publish_time, attributes) alongside the message body in `data`. Matches the design's landing schema."
  type        = bool
  default     = true
}

variable "use_topic_schema" {
  description = "Map the topic's schema onto table columns. Off here — the body is landed whole as JSON in `data` and parsed later by dbt."
  type        = bool
  default     = false
}

variable "drop_unknown_fields" {
  description = "When use_topic_schema is on, silently drop fields absent from the table. Irrelevant while use_topic_schema is false."
  type        = bool
  default     = false
}

# --- Delivery / retention ----------------------------------------------------

variable "ack_deadline_seconds" {
  description = "Seconds Pub/Sub waits for an ack before redelivery."
  type        = number
  default     = 60
}

variable "max_delivery_attempts" {
  description = "Deliveries attempted before a message is dead-lettered to the DLQ topic (min 5)."
  type        = number
  default     = 5
}

variable "message_retention_duration" {
  description = "How long the BigQuery subscription retains unacked messages."
  type        = string
  default     = "604800s" # 7 days
}

variable "dlq_retention_duration" {
  description = "How long the DLQ pull subscription retains dead-lettered messages before they expire. Bounds DLQ growth for a manually-inspected queue."
  type        = string
  default     = "604800s" # 7 days
}
