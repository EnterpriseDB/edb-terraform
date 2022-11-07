/* \n
Terraform Docs: \n
https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network \n
\n
VPC CIDR Block is not here as it has been "Deprecated in favor of subnet mode networks": \n
https://cloud.google.com/compute/docs/reference/rest/v1/networks \n
*/
resource "google_compute_network" "main" {
  name = "${var.vpc_tag}-${var.region}-${var.name_id}"
  auto_create_subnetworks = "false"
  routing_mode = "GLOBAL"
}