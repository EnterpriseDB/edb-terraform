output "ips" {
  value = {
    region   = var.region
    password = var.password
    address  = google_alloydb_instance.main.ip_address
    port     = var.port
  }
}
