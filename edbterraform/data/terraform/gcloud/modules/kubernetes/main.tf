resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  initial_node_count = 1

  network    = var.network
  subnetwork = var.subnetwork

  resource_labels = var.tags
}

resource "google_container_node_pool" "primary_nodes" {
  name       = var.cluster_name
  location   = var.machine.spec.region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    machine_type = var.machine.spec.instance_type
    labels       = var.tags
    tags         = [format("%s-%s", var.cluster_name, "gke-node"), format("%s-%s", var.cluster_name, "gke")]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}