output "instance_type" {
  value = google_compute_instance.machine.machine_type
}
output "type" {
  value = var.machine.spec.type
}
output "zone" {
  value = google_compute_instance.machine.zone
}
output "region" {
  value = var.machine.spec.region
}
output "public_ip" {
  value = google_compute_instance.machine.network_interface.0.access_config.0.nat_ip
}
output "private_ip" {
  value = google_compute_instance.machine.network_interface.0.network_ip
}
