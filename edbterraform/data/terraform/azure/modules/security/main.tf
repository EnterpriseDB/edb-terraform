resource "azurerm_network_security_group" "firewall" {
  name                = "${var.region}-${var.zone}-${var.name_id}"
  resource_group_name = var.resource_name
  location            = var.region
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "firewall" {
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.firewall.id

  depends_on = [
    azurerm_network_security_group.firewall
  ]
}

resource "azurerm_network_security_rule" "rules" {
  for_each = {
    # preserve ordering
    for index, values in var.ports:
      format("0%.3d",index) => values
  }

  resource_group_name         = var.resource_name
  network_security_group_name = azurerm_network_security_group.firewall.name

  name                       = "${each.value.protocol}-${var.region}-${var.zone}-${var.name_id}-${each.key}"
  description                = each.value.description
  # First letter must be uppercase
  protocol                   = title(each.value.protocol)
  destination_port_range     = (
    each.value.port != null && each.value.to_port != null ? "${each.value.port}-${each.value.to_port}" : 
    each.value.port != null ? each.value.port : "*"
    )
  direction                  = lower(each.value.type) == "ingress" ? "Inbound" : "Outbound"
  destination_address_prefixes = lower(each.value.type) == "egress" && each.value.cidrs != null ? each.value.cidrs : var.egress_cidrs
  source_port_range          = "*"
  source_address_prefixes    = lower(each.value.type) == "ingress" && each.value.cidrs != null ? each.value.cidrs : var.ingress_cidrs
  access                     = "Allow"
  priority                   = 100 + tonumber(each.key)

  lifecycle {
    precondition {
      condition     = each.value.type == "ingress" || each.value.type == "egress"
      error_message = "${each.key} has type ${each.value.type}. Must be ingress or egress."
    }
  }
}
