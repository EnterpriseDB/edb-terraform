output "machine_ips" {
  value = {
    type       = var.machine.spec.type
    az         = var.machine.spec.az
    region     = var.machine.spec.region
    public_ip  = google_compute_instance.machine.network_interface.0.access_config.0.nat_ip
    private_ip = google_compute_instance.machine.network_interface.0.network_ip
  }
}

