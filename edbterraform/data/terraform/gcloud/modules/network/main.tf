resource "google_compute_subnetwork" "subnet" {
  name          = var.name
  network       = var.network_name
  ip_cidr_range = var.ip_cidr_range
}
