output "region" {
  value = var.machine.spec.region
}
output "kubernetes_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE Cluster Name"
}
output "kubernetes_cluster_host" {
  value       = google_container_cluster.primary.endpoint
  description = "GKE Cluster Host"
}
output "tags" {
  value = google_container_cluster.primary.labels
}
