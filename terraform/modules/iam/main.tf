###############################################################################
# Module: iam
# Project-level roles for Dev, Ops, SRE, and CI/CD personas, plus the Workload
# Identity bindings used by application service accounts.
###############################################################################

locals {
  role_bindings = flatten([
    for persona, cfg in var.personas : [
      for role in cfg.roles : {
        persona = persona
        member  = cfg.member
        role    = role
      }
    ]
  ])
}

resource "google_project_iam_member" "personas" {
  for_each = {
    for rb in local.role_bindings :
    "${rb.persona}-${rb.role}" => rb
  }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}

# Dedicated service account used by CI/CD to deploy to GKE and push images.
resource "google_service_account" "cicd" {
  project      = var.project_id
  account_id   = var.cicd_sa_id
  display_name = "CI/CD deployer"
}

resource "google_project_iam_member" "cicd_roles" {
  for_each = toset(var.cicd_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.cicd.email}"
}

# Application Google Service Accounts, one per app, bound via Workload Identity
# to a Kubernetes Service Account (configured at deploy time).
resource "google_service_account" "apps" {
  for_each     = toset(var.app_service_accounts)
  project      = var.project_id
  account_id   = each.value
  display_name = "Workload SA for ${each.value}"
}

# Wire Workload Identity: KSA in <ns>/<ksa-name> can impersonate the GSA.
resource "google_service_account_iam_member" "wi_binding" {
  for_each = {
    for app, cfg in var.workload_identity_bindings :
    app => cfg
  }

  service_account_id = google_service_account.apps[each.value.gsa_name].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.ksa_name}]"
}
