# Resource docs: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/alloydb_cluster
resource "google_alloydb_cluster" "main" {
  cluster_id = var.name
  location   = var.region
  network    = var.network
  # value not configurable at the moment
  # database_version = "POSTGRES_14"

  initial_user {
    user     = var.username
    password = var.password
  }

  automated_backup_policy {
    enabled = var.automated_backups
    quantity_based_retention {
      count = var.backup_count
    }
    weekly_schedule {
      start_times {
        hours   = var.backup_start_time.hours
        minutes = var.backup_start_time.minutes
        seconds = var.backup_start_time.seconds
        nanos   = var.backup_start_time.nanos
      }
    }
  }

  labels = local.labels

}

# Resource docs: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/alloydb_instance
resource "google_alloydb_instance" "main" {
  cluster       = google_alloydb_cluster.main.name
  instance_id   = var.name
  instance_type = "PRIMARY"
  /*
  availability_type (Optional) - Availability type of an Instance:
  - From resource docs - v4.53.0:
    - Defaults to REGIONAL for both primary and read instances.
      - Note that primary and read instances can have different availability types.
    - Possible values are: AVAILABILITY_TYPE_UNSPECIFIED, ZONAL, REGIONAL.
  - Additions to resource docs - v4.71.0:
    - Only READ_POOL instance supports ZONAL type.
    - Users can't specify the zone for READ_POOL instance.
    - Zone is automatically chosen from the list of zones in the region specified.
    - Read pool of size 1 can only have zonal availability.
    - Read pools with node count of 2 or more can have regional availability (nodes are present in 2 or more zones in a region).'*/
  availability_type = "REGIONAL"

  database_flags = {
    for setting in var.settings :
    setting.name => setting.value
  }

  machine_config {
    cpu_count = var.cpu_count
  }

  depends_on = [google_alloydb_cluster.main]

  labels = local.labels
}
