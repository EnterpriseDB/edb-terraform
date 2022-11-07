variable "ssh_pub_key" {}
variable "ssh_user" {}
variable "name_id" { default = "0" }
variable "region" { default = "0" }

resource "google_compute_project_metadata_item" "key_pair" {
    key = "ssh-keys-${var.region}-${var.name_id}"
    value = "${var.ssh_user}:${file(var.ssh_pub_key)}"
}