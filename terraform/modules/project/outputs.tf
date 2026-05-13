output "project_id" {
  description = "The created project ID."
  value       = google_project.this.project_id
}

output "project_number" {
  description = "The numeric project number."
  value       = google_project.this.number
}

output "enabled_apis" {
  description = "List of APIs enabled on the project."
  value       = [for s in google_project_service.apis : s.service]
}
