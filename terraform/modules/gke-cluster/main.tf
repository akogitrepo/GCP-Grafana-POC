###############################################################################
# Module: gke-cluster
# Reusable GKE Standard cluster module. Private cluster, VPC-native, Workload
# Identity, Shielded Nodes, release channel REGULAR, separate system + app
# node pools.
###############################################################################

resource "google_service_account" "node_sa" {
  project      = var.project_id
  account_id   = "${var.cluster_name}-node"
  display_name = "Node SA for ${var.cluster_name}"
}

# Minimum roles for the node SA (least privilege).
resource "google_project_iam_member" "node_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader"
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}

resource "google_container_cluster" "this" {
  project    = var.project_id
  name       = var.cluster_name
  location   = var.region
  network    = var.network
  subnetwork = var.subnetwork

  # We manage node pools separately.
  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  release_channel {
    channel = "REGULAR"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr
        display_name = cidr_blocks.value.name
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "API_SERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER"
    ]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "APISERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER",
      "STORAGE",
      "HPA",
      "POD",
      "DAEMONSET",
      "DEPLOYMENT",
      "STATEFULSET"
    ]
    managed_prometheus {
      enabled = true
    }
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  dns_config {
    cluster_dns       = "CLOUD_DNS"
    cluster_dns_scope = "CLUSTER_SCOPE"
  }

  cost_management_config {
    enabled = true
  }

  resource_labels = var.labels

  lifecycle {
    ignore_changes = [
      initial_node_count,
      node_pool # we manage node pools out-of-band
    ]
  }
}

# System node pool (small, runs ingress, DNS, system add-ons).
resource "google_container_node_pool" "system" {
  project    = var.project_id
  name       = "system"
  location   = var.region
  cluster    = google_container_cluster.this.name

  initial_node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = "e2-standard-2"
    disk_size_gb    = 50
    disk_type       = "pd-balanced"
    service_account = google_service_account.node_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    taint {
      key    = "system"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    tags   = ["gke-node", "${var.cluster_name}-system"]
    labels = merge(var.labels, { pool = "system" })
  }
}

# General app node pool — runs web-app-a and web-app-b workloads.
resource "google_container_node_pool" "apps" {
  project  = var.project_id
  name     = "apps"
  location = var.region
  cluster  = google_container_cluster.this.name

  initial_node_count = var.app_pool_min_nodes

  autoscaling {
    min_node_count = var.app_pool_min_nodes
    max_node_count = var.app_pool_max_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = var.app_machine_type
    disk_size_gb    = 100
    disk_type       = "pd-balanced"
    service_account = google_service_account.node_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    tags   = ["gke-node", "${var.cluster_name}-apps"]
    labels = merge(var.labels, { pool = "apps" })
  }
}
