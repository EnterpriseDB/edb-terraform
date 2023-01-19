/*
https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance
*/
resource "google_sql_database_instance" "instance" {

  name = var.name
  # https://cloud.google.com/sql/docs/db-versions
  # Must be uppercase with underscore separators
  database_version = (format("%s_%s",
    upper(var.engine),
    upper(replace(var.engine_version, ".", "_"))
    )
  )

  settings {
    tier                  = var.instance_type
    disk_size             = var.disk_size
    disk_type             = upper(replace(var.disk_type, ".", "_"))
    disk_autoresize       = var.autoresize
    disk_autoresize_limit = (var.autoresize ? var.autoresize_limit : null)
    user_labels = var.tags

    location_preference {
      zone = var.zone
    }

    ip_configuration {
      ipv4_enabled    = var.public_access
      private_network = var.network
    }

    dynamic "database_flags" {
      for_each = var.settings
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }
  }

  deletion_protection = var.deletion_protection

}

resource "google_sql_database" "db" {
  name     = var.dbname
  instance = google_sql_database_instance.instance.name

  depends_on = [google_sql_database_instance.instance]
}

resource "google_sql_user" "user" {
  name     = var.username
  instance = google_sql_database_instance.instance.name
  password = var.password

  depends_on = [google_sql_database_instance.instance]
}
