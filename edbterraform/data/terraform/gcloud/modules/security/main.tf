resource "google_compute_firewall" "rules" {
  for_each = {
    # preserve ordering
    for index, values in var.ports:
      format("0%.4d",index) => values
  }
  name    = "${each.value.protocol}-${var.region}-${var.name_id}-${each.key}"
  network = var.network_name
  priority = each.key
  dynamic "allow" {
    for_each = each.value.access != "deny" ? { "0" : each.value } : {}
    content {
      protocol = allow.value.protocol
      ports    = (
        allow.value.port != null && allow.value.to_port != null ? ["${allow.value.port}-${allow.value.to_port}"] :
        allow.value.port != null ? [allow.value.port] : []
      )
    }
  }
  dynamic "deny" {
    for_each = each.value.access == "deny" ? { "0" : each.value } : {}
    content {
      protocol = deny.value.protocol
      ports    = (
        deny.value.port != null && deny.value.to_port != null ? ["${deny.value.port}-${deny.value.to_port}"] :
        deny.value.port != null ? [deny.value.port] : []
      )
    }
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
