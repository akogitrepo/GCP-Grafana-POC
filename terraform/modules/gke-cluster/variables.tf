variable "project_id" {
  description = "Target project."
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name."
  type        = string
}

variable "region" {
  description = "Regional GKE location (e.g. us-central1)."
  type        = string
}

variable "network" {
  description = "VPC self link."
  type        = string
}

variable "subnetwork" {
  description = "Subnet self link for the cluster."
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary range used for Pods."
  type        = string
}

variable "services_range_name" {
  description = "Name of the secondary range used for Services."
  type        = string
}

variable "master_cidr" {
  description = "Control plane CIDR (/28)."
  type        = string
}

variable "master_authorized_networks" {
  description = "CIDRs allowed to reach the public control plane endpoint."
  type = list(object({
    cidr = string
    name = string
  }))
  default = []
}

variable "app_machine_type" {
  description = "Machine type for app node pool."
  type        = string
  default     = "e2-standard-4"
}

variable "app_pool_min_nodes" {
  description = "Min nodes per zone in the app pool."
  type        = number
  default     = 2
}

variable "app_pool_max_nodes" {
  description = "Max nodes per zone in the app pool."
  type        = number
  default     = 10
}

variable "labels" {
  description = "Cluster + pool labels."
  type        = map(string)
  default     = {}
}
