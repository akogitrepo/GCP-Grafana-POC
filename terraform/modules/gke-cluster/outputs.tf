output "cluster_name" {
  value = google_container_cluster.this.name
}

output "cluster_endpoint" {
  value     = google_container_cluster.this.endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive = true
}

output "cluster_location" {
  value = google_container_cluster.this.location
}

output "node_service_account_email" {
  value = google_service_account.node_sa.email
}
