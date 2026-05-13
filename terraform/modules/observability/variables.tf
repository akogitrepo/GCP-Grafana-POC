variable "project_id" {
  type = string
}

variable "logs_dataset_id" {
  type    = string
  default = "platform_logs"
}

variable "bq_location" {
  type    = string
  default = "US"
}

variable "log_retention_days" {
  type    = number
  default = 60
}

variable "log_filter" {
  description = "Logs filter for what to export to BigQuery."
  type        = string
  default     = <<EOT
resource.type = "k8s_container"
OR resource.type = "k8s_cluster"
OR resource.type = "gce_instance"
OR resource.type = "http_load_balancer"
OR resource.type = "gce_network"
EOT
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "alert_emails" {
  description = "Emails to notify on critical alerts."
  type        = list(string)
  default     = []
}

variable "uptime_host" {
  description = "Public hostname to check (set empty to skip)."
  type        = string
  default     = ""
}
