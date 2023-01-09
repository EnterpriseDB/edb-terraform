output "region" {
  value = var.region
}
output "zone" {
  value = google_alloydb_instance.main.gce_zone
}
output "username" {
  value = google_alloydb_cluster.main.initial_user.0.user
}
output "password" {
  value = google_alloydb_cluster.main.initial_user.0.password
}
output "private_ip" {
  value = google_alloydb_instance.main.ip_address
}
output "port" {
  value = var.port
}
output "version" {
  value = google_alloydb_cluster.main.database_version
}
