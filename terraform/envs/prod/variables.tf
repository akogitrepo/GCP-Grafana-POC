variable "project_id"      { type = string }
variable "project_name"    { type = string  default = "platform-prod" }
variable "folder_id"       { type = string  default = null }
variable "billing_account" { type = string }

variable "primary_region"   { type = string  default = "us-central1" }
variable "secondary_region" { type = string  default = "us-east1" }

variable "hostnames" {
  description = "Hostnames served by the global LB."
  type        = list(string)
  default     = ["www.example.com"]
}

variable "alert_emails" {
  type    = list(string)
  default = []
}

variable "personas" {
  description = "Persona -> { member, roles }. See modules/iam/variables.tf."
  type = map(object({
    member = string
    roles  = list(string)
  }))
  default = {}
}
