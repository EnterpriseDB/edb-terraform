resource "google_compute_global_address" "sql_private_ip" {

  name          = var.name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network
}

resource "google_service_networking_connection" "vpc_connection" {

  network                 = var.network
  service                 = var.google_service_url
  reserved_peering_ranges = [google_compute_global_address.sql_private_ip.name]

  depends_on = [google_compute_global_address.sql_private_ip]
}
