resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  description   = "Container images for platform workloads."
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-last-30"
    action = "KEEP"
    most_recent_versions {
      keep_count = 30
    }
  }

  cleanup_policies {
    id     = "delete-untagged-older-than-30d"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "2592000s" # 30 days
    }
  }
}
