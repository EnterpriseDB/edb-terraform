resource "google_compute_project_metadata_item" "key_pair" {
  key   = var.key_name
  value = "${var.ssh_user}:${var.public_keys}"
}