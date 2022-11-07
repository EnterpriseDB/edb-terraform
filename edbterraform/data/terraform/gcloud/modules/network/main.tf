variable "public_subnet_tag" {}
variable "network_name" {}
variable "ip_cidr_range" {}
variable "name_id" { default = "0" }
variable "name" { default = "name" }

resource "google_compute_subnetwork" "public_subnets" {
  name          = var.name
  network       = var.network_name
  ip_cidr_range = var.ip_cidr_range
}
