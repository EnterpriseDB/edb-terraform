resource "google_compute_firewall" "rules" {
  for_each = {
    # preserve ordering
    for index, values in var.ports:
      format("0%.3d",index) => values
  }
  name    = "${each.value.protocol}-${var.region}-${var.name_id}-${each.key}"
  network = var.network_name
  allow {
    protocol = each.value.protocol
    ports    = each.value.port != null ? [each.value.port] : []
  }
  source_ranges = each.value.ingress_cidrs != null ? each.value.ingress_cidrs : var.ingress_cidrs
  destination_ranges = each.value.egress_cidrs != null ? each.value.egress_cidrs : var.egress_cidrs
}
