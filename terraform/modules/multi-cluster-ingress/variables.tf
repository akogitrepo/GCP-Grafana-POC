variable "project_id" {
  description = "Project hosting fleet + LB."
  type        = string
}

variable "clusters" {
  description = "Map of cluster key -> { cluster_name, cluster_resource_link }."
  type = map(object({
    cluster_name          = string
    cluster_resource_link = string # e.g. //container.googleapis.com/projects/.../locations/.../clusters/...
  }))
}

variable "config_membership_key" {
  description = "Key from var.clusters that should host the MCI config-cluster."
  type        = string
}

variable "lb_name" {
  description = "Name prefix for global LB resources."
  type        = string
  default     = "platform-edge"
}

variable "hostnames" {
  description = "Public hostnames for the managed SSL cert."
  type        = list(string)
}
