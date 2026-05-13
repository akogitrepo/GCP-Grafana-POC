###############################################################################
# Module: multi-cluster-ingress
# Registers both GKE clusters to Fleet (GKE Hub), enables Multi-Cluster Ingress
# (MCI) and Multi-Cluster Services (MCS), and sets the config-cluster.
#
# The MultiClusterIngress / MultiClusterService objects themselves are applied
# as Kubernetes manifests against the config-cluster (see kubernetes/ingress/).
###############################################################################

resource "google_gke_hub_membership" "memberships" {
  for_each = var.clusters

  project       = var.project_id
  membership_id = "${each.value.cluster_name}-membership"
  location      = "global"

  endpoint {
    gke_cluster {
      resource_link = each.value.cluster_resource_link
    }
  }
}

resource "google_gke_hub_feature" "mci" {
  project  = var.project_id
  name     = "multiclusteringress"
  location = "global"

  spec {
    multiclusteringress {
      config_membership = google_gke_hub_membership.memberships[var.config_membership_key].id
    }
  }
}

resource "google_gke_hub_feature" "mcsd" {
  project  = var.project_id
  name     = "multiclusterservicediscovery"
  location = "global"
}

# Reserve a global static IP for the external HTTPS LB created by MCI.
resource "google_compute_global_address" "external_lb" {
  project = var.project_id
  name    = "${var.lb_name}-ip"
}

# Managed SSL certificate for the public hostname.
resource "google_compute_managed_ssl_certificate" "edge" {
  project = var.project_id
  name    = "${var.lb_name}-cert"

  managed {
    domains = var.hostnames
  }
}
