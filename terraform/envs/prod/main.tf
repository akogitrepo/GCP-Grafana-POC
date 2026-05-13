###############################################################################
# Prod environment composition.
# Order of operations:
#   1. project (APIs)
#   2. network (VPC + 2 subnets + NAT)
#   3. iam, artifact-registry, cloud-armor, observability
#   4. gke-cluster x 2  (primary in us-central1, secondary in us-east1)
#   5. multi-cluster-ingress (fleet registration + global LB)
###############################################################################

locals {
  labels = {
    environment = "prod"
    managed_by  = "terraform"
    component   = "platform"
  }

  subnets = {
    primary = {
      name          = "gke-primary-subnet"
      region        = var.primary_region
      cidr          = "10.10.0.0/20"
      pods_cidr     = "10.20.0.0/14"
      services_cidr = "10.40.0.0/20"
    }
    secondary = {
      name          = "gke-secondary-subnet"
      region        = var.secondary_region
      cidr          = "10.50.0.0/20"
      pods_cidr     = "10.60.0.0/14"
      services_cidr = "10.80.0.0/20"
    }
  }
}

module "project" {
  source = "../../modules/project"

  project_name    = var.project_name
  project_id      = var.project_id
  folder_id       = var.folder_id
  billing_account = var.billing_account
  labels          = local.labels
}

module "network" {
  source       = "../../modules/network"
  project_id   = module.project.project_id
  network_name = "platform-vpc"
  subnets      = local.subnets

  depends_on = [module.project]
}

module "iam" {
  source     = "../../modules/iam"
  project_id = module.project.project_id
  personas   = var.personas

  workload_identity_bindings = {
    web-app-a = {
      gsa_name  = "web-app-a-sa"
      namespace = "web-app-a"
      ksa_name  = "web-app-a"
    }
    web-app-b = {
      gsa_name  = "web-app-b-sa"
      namespace = "web-app-b"
      ksa_name  = "web-app-b"
    }
  }
}

module "artifact_registry" {
  source     = "../../modules/artifact-registry"
  project_id = module.project.project_id
  location   = "us"
}

module "cloud_armor" {
  source     = "../../modules/cloud-armor"
  project_id = module.project.project_id
}

module "observability" {
  source       = "../../modules/observability"
  project_id   = module.project.project_id
  labels       = local.labels
  alert_emails = var.alert_emails
  uptime_host  = var.hostnames[0]
}

module "gke_primary" {
  source = "../../modules/gke-cluster"

  project_id          = module.project.project_id
  cluster_name        = "gke-primary"
  region              = var.primary_region
  network             = module.network.vpc_self_link
  subnetwork          = module.network.subnets["primary"]
  pods_range_name     = module.network.subnet_secondary_ranges["primary"].pods_range
  services_range_name = module.network.subnet_secondary_ranges["primary"].services_range
  master_cidr         = "172.16.0.0/28"
  labels              = local.labels
}

module "gke_secondary" {
  source = "../../modules/gke-cluster"

  project_id          = module.project.project_id
  cluster_name        = "gke-secondary"
  region              = var.secondary_region
  network             = module.network.vpc_self_link
  subnetwork          = module.network.subnets["secondary"]
  pods_range_name     = module.network.subnet_secondary_ranges["secondary"].pods_range
  services_range_name = module.network.subnet_secondary_ranges["secondary"].services_range
  master_cidr         = "172.16.0.16/28"
  labels              = local.labels
}

module "mci" {
  source = "../../modules/multi-cluster-ingress"

  project_id = module.project.project_id
  clusters = {
    primary = {
      cluster_name          = module.gke_primary.cluster_name
      cluster_resource_link = "//container.googleapis.com/projects/${module.project.project_id}/locations/${var.primary_region}/clusters/${module.gke_primary.cluster_name}"
    }
    secondary = {
      cluster_name          = module.gke_secondary.cluster_name
      cluster_resource_link = "//container.googleapis.com/projects/${module.project.project_id}/locations/${var.secondary_region}/clusters/${module.gke_secondary.cluster_name}"
    }
  }
  config_membership_key = "primary"
  hostnames             = var.hostnames
}
