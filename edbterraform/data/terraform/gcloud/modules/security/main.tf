variable "network_name" {}
variable "public_cidrblock" {}
variable "project_tag" {}
variable "service_ports" {}
variable "cluster_name" {}
variable "region_cidrblocks" {}
variable "region_ports" {}
variable "name_id" { default = "0" }
variable "region" { default = "0" }

resource "google_compute_firewall" "service" {
  count = length(try(var.service_ports, [])) > 0 ? 1 : 0
  
  name    = "service-${count.index}-${var.region}-${var.name_id}"
  network = var.network_name

  dynamic "allow" {
    for_each = var.service_ports
    iterator = service_port
    
    content {
      protocol = service_port.value.protocol
      ports = length(tostring(try(service_port.value.port, ""))) > 0 ? [service_port.value.port] : []
    }
  }

  source_ranges = [var.public_cidrblock]
}

resource "google_compute_firewall" "zones" {
  count = length(try(var.region_ports, [])) > 0 ? 1 : 0

  name    = "zone-${count.index}-${var.region}-${var.name_id}"
  network = var.network_name

  dynamic "allow" {
    for_each = var.region_ports
    iterator = region_port
    
    content {
      protocol = region_port.value.protocol
      ports = length(tostring(try(region_port.value.port, ""))) > 0 ? [region_port.value.port] : []
    }
  }

  source_ranges = var.region_cidrblocks
}