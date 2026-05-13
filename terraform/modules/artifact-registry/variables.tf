variable "project_id" {
  type = string
}

variable "location" {
  description = "Multi-region or region for the repository (e.g. us)."
  type        = string
  default     = "us"
}

variable "repository_id" {
  type    = string
  default = "platform-images"
}
