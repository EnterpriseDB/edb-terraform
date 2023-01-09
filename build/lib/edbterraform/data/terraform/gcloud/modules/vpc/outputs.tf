output "vpc_id" {
  value = google_compute_network.main.id
}

# Autocreated by GCP for routing out of the network
output "vpc_cidr_block" {
  value = google_compute_network.main.gateway_ipv4
}

output "name" {
  value = google_compute_network.main.name
}
