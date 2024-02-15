resource "azurerm_network_security_rule" "rules" {
  for_each = {
    # preserve ordering
    # 100-4096 priorities allowed by Azure
    for idx, values in var.ports:
      format("0%.4d",idx+100) => values
  }

  resource_group_name         = var.resource_name
  network_security_group_name = var.security_group_name

  name                       = replace(join("-", formatlist("%#v", [each.value.protocol, each.value.port, each.value.to_port, each.value.type, each.key, var.name_id])), "\"", "")
  description                = each.value.description
  # First letter must be uppercase
  protocol                   = title(each.value.protocol)
  destination_port_range     = (
    each.value.port != null && each.value.to_port != null ? "${each.value.port}-${each.value.to_port}" : 
    each.value.port != null ? each.value.port : "*"
    )
  direction                  = lower(each.value.type) == "ingress" ? "Inbound" : "Outbound"
  source_port_range          = "*"
  source_address_prefixes    = lower(each.value.type) == "ingress" ? concat(each.value.cidrs,
                                           try(each.value.defaults, "") == "service" ? var.service_cidrblocks :
                                           try(each.value.defaults, "") == "public" ? var.public_cidrblocks :
                                           try(each.value.defaults, "") == "internal" ? var.internal_cidrblocks :
                                           []
                                         ) : local.target_cidrblocks
  destination_address_prefixes = lower(each.value.type) == "ingress" ? local.target_cidrblocks : concat(each.value.cidrs,
                                             try(each.value.defaults, "") == "service" ? var.service_cidrblocks :
                                             try(each.value.defaults, "") == "public" ? var.public_cidrblocks :
                                             try(each.value.defaults, "") == "internal" ? var.internal_cidrblocks :
                                             []
                                            )
  access                     = lower(each.value.access) == "deny" ? "Deny" : "Allow"
  priority                   = tonumber(each.key)

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
