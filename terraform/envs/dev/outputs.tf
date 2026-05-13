output "project_id"            { value = module.project.project_id }
output "primary_cluster"       { value = module.gke_primary.cluster_name }
output "secondary_cluster"     { value = module.gke_secondary.cluster_name }
output "global_lb_ip"          { value = module.mci.global_ip_address }
output "artifact_registry_url" { value = module.artifact_registry.repository_url }
output "logs_dataset_id"       { value = module.observability.logs_dataset_id }
