variable "project_id" {
  description = "Target project."
  type        = string
}

variable "personas" {
  description = <<EOT
Map of persona => { member, roles }.
Example:
{
  dev = {
    member = "group:devs@example.com"
    roles  = ["roles/container.developer", "roles/logging.viewer"]
  }
}
EOT
  type = map(object({
    member = string
    roles  = list(string)
  }))
  default = {}
}

variable "cicd_sa_id" {
  description = "Account ID for the CI/CD service account."
  type        = string
  default     = "cicd-deployer"
}

variable "cicd_roles" {
  description = "Project roles granted to the CI/CD service account."
  type        = list(string)
  default = [
    "roles/container.developer",
    "roles/artifactregistry.writer",
    "roles/cloudbuild.builds.editor",
    "roles/iam.serviceAccountUser",
    "roles/logging.logWriter"
  ]
}

variable "app_service_accounts" {
  description = "List of Google service accounts to create for workloads."
  type        = list(string)
  default     = ["web-app-a-sa", "web-app-b-sa"]
}

variable "workload_identity_bindings" {
  description = "Map of app key -> { gsa_name, namespace, ksa_name }."
  type = map(object({
    gsa_name  = string
    namespace = string
    ksa_name  = string
  }))
  default = {}
}
