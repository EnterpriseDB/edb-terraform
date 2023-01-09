output "key_pair_id" {
  value = google_compute_project_metadata_item.key_pair.id
}

output "keys" {
  value = google_compute_project_metadata_item.key_pair.value
}