resource "google_compute_firewall" "services" {
  count = length(var.service_ports) > 0 ? 1 : 0

  name    = var.service_name
  network = var.network_name

  dynamic "allow" {
    for_each = var.service_ports
    iterator = service_port

    content {
      protocol = service_port.value.protocol
      ports    = service_port.value.port != null ? [service_port.value.port] : []
    }
  }

  source_ranges = [var.public_cidrblock]
}

resource "google_compute_firewall" "regions" {
  count = length(var.region_ports) > 0 ? 1 : 0

  name    = var.region_name
  network = var.network_name

  dynamic "allow" {
    for_each = var.region_ports
    iterator = region_port

    content {
      protocol = region_port.value.protocol
      ports    = region_port.value.port != null ? [region_port.value.port] : []
    }
  }

  source_ranges = var.region_cidrblocks
}