variable "project_id" {
  description = "Project the VPC is created in."
  type        = string
}

variable "network_name" {
  description = "VPC name."
  type        = string
  default     = "platform-vpc"
}

variable "subnets" {
  description = <<EOT
Map of subnets keyed by cluster nickname (e.g. primary, secondary).
Each entry must include name, region, cidr, pods_cidr, services_cidr.
EOT
  type = map(object({
    name          = string
    region        = string
    cidr          = string
    pods_cidr     = string
    services_cidr = string
  }))
}
