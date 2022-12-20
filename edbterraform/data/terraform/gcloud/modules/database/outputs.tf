output "database_ips" {
  value = {
    region    = var.region
    username  = var.username
    password  = var.password
    address   = google_sql_database_instance.instance.private_ip_address
    public_ip = google_sql_database_instance.instance.public_ip_address
    port      = var.port
    dbname    = google_sql_database.db.name
  }
}
