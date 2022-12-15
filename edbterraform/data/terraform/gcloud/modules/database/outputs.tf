output "database_ips" {
  value = {
    region   = var.region
    username = var.username
    password = var.password
    address  = google_sql_database_instance.instance.ip_address.0.ip_address
    port     = var.port
    dbname   = google_sql_database.db.name
  }
}
