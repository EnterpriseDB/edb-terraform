/*
https://cloud.google.com/vpc/docs/vpc-peering
https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering
*/
resource "google_compute_network_peering" "peering" {
  name         = var.peering_name
  network      = var.network
  peer_network = var.peer_network
}
