output "vpc_id" {
  description = "Self link of the VPC."
  value       = google_compute_network.vpc.id
}

output "vpc_self_link" {
  value = google_compute_network.vpc.self_link
}

output "subnets" {
  description = "Map of cluster nickname -> subnet self_link."
  value       = { for k, s in google_compute_subnetwork.cluster : k => s.self_link }
}

output "subnet_secondary_ranges" {
  description = "Map of cluster nickname -> {pods_range, services_range} names."
  value = {
    for k, s in google_compute_subnetwork.cluster : k => {
      pods_range     = "${s.name}-pods"
      services_range = "${s.name}-services"
    }
  }
}
