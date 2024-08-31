resource "google_compute_firewall" "rules" {
  for_each = {
    # preserve ordering
    for index, values in var.ports:
      format("0%.4d",index) => values
  }
  # name restricted to 63 characters, lowercase, digits, and dashes
  name    = replace(lower(substr("${each.value.protocol}-${var.region}-${var.name_id}-${each.key}", 0, 63)), "_", "-")
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
  source_ranges = lower(each.value.type) == "ingress" ? concat(each.value.cidrs,
                              try(each.value.defaults, "") == "service" ? var.service_cidrblocks :
                              try(each.value.defaults, "") == "public" ? var.public_cidrblocks :
                              try(each.value.defaults, "") == "internal" ? var.internal_cidrblocks :
                              []
                            ) : local.target_cidrblocks
  destination_ranges = lower(each.value.type) == "ingress" ? local.target_cidrblocks : concat(each.value.cidrs,
                                   try(each.value.defaults, "") == "service" ? var.service_cidrblocks :
                                   try(each.value.defaults, "") == "public" ? var.public_cidrblocks :
                                   try(each.value.defaults, "") == "internal" ? var.internal_cidrblocks :
                                   []
                                 )

  lifecycle {
    precondition {
      condition     = each.value.type == "ingress" || each.value.type == "egress"
      error_message = "${each.key} has type ${each.value.type}. Must be ingress or egress."
    }

    precondition {
      error_message = "port defaults must be one of: service, public, internal or an empty string ('')"
      condition = contains(["service", "internal", "public", ""], try(each.value.defaults, ""))
    }
  }
}
