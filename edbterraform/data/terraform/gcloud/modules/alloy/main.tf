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

  labels = var.tags

}

resource "google_alloydb_instance" "main" {
  cluster       = google_alloydb_cluster.main.name
  instance_id   = var.name
  instance_type = "PRIMARY"
  # ZONAL only available for READ_POOL instances
  availability_type = "REGIONAL"

  database_flags = {
    for setting in var.settings :
    setting.name => setting.value
  }

  machine_config {
    cpu_count = var.cpu_count
  }

  depends_on = [google_alloydb_cluster.main]

  labels = var.tags
}
