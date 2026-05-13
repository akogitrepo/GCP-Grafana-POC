###############################################################################
# Module: network
# Creates the platform VPC with one subnet per region (for two GKE clusters),
# secondary ranges for Pods/Services (VPC-native), Cloud NAT for egress, and
# baseline firewall rules.
###############################################################################

resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  mtu                     = 1460
}

# One subnet per cluster region. Each subnet has dedicated alias ranges for
# Pods and Services so the clusters are VPC-native.
resource "google_compute_subnetwork" "cluster" {
  for_each = var.subnets

  project                  = var.project_id
  name                     = each.value.name
  region                   = each.value.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = each.value.cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "${each.value.name}-pods"
    ip_cidr_range = each.value.pods_cidr
  }
  secondary_ip_range {
    range_name    = "${each.value.name}-services"
    ip_cidr_range = each.value.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Cloud Router + NAT for outbound internet egress from private nodes.
resource "google_compute_router" "router" {
  for_each = var.subnets

  project = var.project_id
  name    = "${each.value.name}-router"
  region  = each.value.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  for_each = var.subnets

  project                            = var.project_id
  name                               = "${each.value.name}-nat"
  router                             = google_compute_router.router[each.key].name
  region                             = each.value.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Private Service Access for Cloud SQL / Memorystore peering.
resource "google_compute_global_address" "psa_range" {
  project       = var.project_id
  name          = "${var.network_name}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa_range.name]
}

# Allow IAP-based SSH to nodes for break-glass.
resource "google_compute_firewall" "iap_ssh" {
  project   = var.project_id
  name      = "${var.network_name}-allow-iap-ssh"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["35.235.240.0/20"] # Google IAP range
  target_tags   = ["gke-node"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Allow Google health-checkers to reach NEGs / LB-backed services.
resource "google_compute_firewall" "google_health_checks" {
  project   = var.project_id
  name      = "${var.network_name}-allow-hc"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]
  target_tags = ["gke-node"]

  allow {
    protocol = "tcp"
  }
}
