###############################################################################
# Module: project
# Creates a new GCP project under a folder, links billing, and enables APIs.
###############################################################################

resource "google_project" "this" {
  name                = var.project_name
  project_id          = var.project_id
  folder_id           = var.folder_id
  billing_account     = var.billing_account
  auto_create_network = false
  labels              = var.labels
}

# Enable required APIs for GKE + observability + supporting services.
resource "google_project_service" "apis" {
  for_each = toset(var.activate_apis)

  project                    = google_project.this.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}

# Default service account is removed for least-privilege; create a project-level
# log sink to a BigQuery dataset for centralized observability later (handled in
# the observability module).
