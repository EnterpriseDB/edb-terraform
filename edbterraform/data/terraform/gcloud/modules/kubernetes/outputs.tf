output "region" {
  value = var.machine.spec.region
}
output "cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE Cluster Name"
}
output "host" {
  value       = google_container_cluster.primary.endpoint
  description = "GKE Cluster Host"
}
output "tags" {
  value = google_container_cluster.primary.resource_labels
}
