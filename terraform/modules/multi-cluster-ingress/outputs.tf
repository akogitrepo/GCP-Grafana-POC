output "global_ip_address" {
  value = google_compute_global_address.external_lb.address
}

output "global_ip_name" {
  value = google_compute_global_address.external_lb.name
}

output "managed_cert_name" {
  value = google_compute_managed_ssl_certificate.edge.name
}

output "memberships" {
  value = { for k, m in google_gke_hub_membership.memberships : k => m.id }
}
