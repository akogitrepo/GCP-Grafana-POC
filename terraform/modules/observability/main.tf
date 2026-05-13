###############################################################################
# Module: observability
# Centralized logs to BigQuery (for Grafana dashboards), metrics scope, uptime
# checks, notification channels, and a few foundational alert policies.
###############################################################################

# BigQuery dataset receiving log exports.
resource "google_bigquery_dataset" "logs" {
  project                    = var.project_id
  dataset_id                 = var.logs_dataset_id
  location                   = var.bq_location
  description                = "Centralized log sink for Grafana dashboards."
  delete_contents_on_destroy = false

  default_table_expiration_ms = var.log_retention_days * 24 * 60 * 60 * 1000
  labels                      = var.labels
}

# Project-level log sink → BigQuery (application + GKE control plane + node logs).
resource "google_logging_project_sink" "to_bq" {
  project                = var.project_id
  name                   = "${var.logs_dataset_id}-sink"
  destination            = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.logs.dataset_id}"
  filter                 = var.log_filter
  unique_writer_identity = true

  bigquery_options {
    use_partitioned_tables = true
  }
}

# Grant the sink's writer identity BigQuery dataEditor on the dataset.
resource "google_bigquery_dataset_iam_member" "sink_writer" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.logs.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.to_bq.writer_identity
}

# Notification channel for alerts (email).
resource "google_monitoring_notification_channel" "email" {
  count        = length(var.alert_emails) > 0 ? 1 : 0
  project      = var.project_id
  display_name = "platform-oncall-email"
  type         = "email"
  labels = {
    email_address = var.alert_emails[0]
  }
}

# Baseline alert: high 5xx rate on the global LB.
resource "google_monitoring_alert_policy" "lb_5xx" {
  project      = var.project_id
  display_name = "Global LB 5xx rate above threshold"
  combiner     = "OR"

  conditions {
    display_name = "LB 5xx rate > 1%"
    condition_threshold {
      filter          = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\" metric.label.\"response_code_class\"=\"500\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.01
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = length(var.alert_emails) > 0 ? [google_monitoring_notification_channel.email[0].id] : []
}

# Uptime check for the public hostname.
resource "google_monitoring_uptime_check_config" "https" {
  count        = var.uptime_host != "" ? 1 : 0
  project      = var.project_id
  display_name = "uptime-${var.uptime_host}"
  timeout      = "10s"
  period       = "60s"

  http_check {
    use_ssl     = true
    path        = "/healthz"
    port        = 443
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      host       = var.uptime_host
      project_id = var.project_id
    }
  }
}
