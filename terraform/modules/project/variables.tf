variable "project_name" {
  description = "Display name for the project."
  type        = string
}

variable "project_id" {
  description = "Globally unique project ID (lowercase, hyphenated)."
  type        = string
}

variable "folder_id" {
  description = "Parent folder ID (folders/NNNNN). Set to null to attach to org."
  type        = string
  default     = null
}

variable "billing_account" {
  description = "Billing account ID to link (e.g. ABCDEF-012345-6789AB)."
  type        = string
}

variable "labels" {
  description = "Project-level labels for cost allocation and inventory."
  type        = map(string)
  default     = {}
}

variable "activate_apis" {
  description = "List of GCP APIs to enable."
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "cloudprofiler.googleapis.com",
    "clouderrorreporting.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "binaryauthorization.googleapis.com",
    "containeranalysis.googleapis.com",
    "networkconnectivity.googleapis.com",
    "dns.googleapis.com",
    "bigquery.googleapis.com",
    "pubsub.googleapis.com",
    "cloudkms.googleapis.com",
    "servicenetworking.googleapis.com",
    "anthos.googleapis.com",
    "gkehub.googleapis.com",
    "multiclusteringress.googleapis.com",
    "multiclusterservicediscovery.googleapis.com",
    "trafficdirector.googleapis.com",
    "meshconfig.googleapis.com"
  ]
}
