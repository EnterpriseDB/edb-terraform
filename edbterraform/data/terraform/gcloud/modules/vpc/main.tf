/*
Terraform Docs:
https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network

VPC CIDR Block is not here as it has been "Deprecated in favor of subnet mode networks":
https://cloud.google.com/compute/docs/reference/rest/v1/networks
*/
resource "google_compute_network" "main" {
  name                    = var.network_name
  auto_create_subnetworks = "false"
  routing_mode            = "GLOBAL"
}