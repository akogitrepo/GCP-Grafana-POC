output "logs_dataset_id" {
  value = google_bigquery_dataset.logs.dataset_id
}

output "logs_dataset_self_link" {
  value = google_bigquery_dataset.logs.self_link
}

output "log_sink_writer_identity" {
  value = google_logging_project_sink.to_bq.writer_identity
}
