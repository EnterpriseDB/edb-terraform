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
    ports    = (
      each.value.port != null && each.value.to_port != null ? ["${each.value.port}-${each.value.to_port}"] :
      each.value.port != null ? [each.value.port] : []
    )
  }
  direction = lower(each.value.type) == "ingress" ? "INGRESS" : "EGRESS"
  source_ranges = lower(each.value.type) == "ingress" && each.value.cidrs != null ? each.value.cidrs : var.ingress_cidrs
  destination_ranges = lower(each.value.type) == "egress" && each.value.cidrs != null ? each.value.cidrs : var.egress_cidrs

  lifecycle {
    precondition {
      condition     = each.value.type == "ingress" || each.value.type == "egress"
      error_message = "${each.key} has type ${each.value.type}. Must be ingress or egress."
    }
  }
}
