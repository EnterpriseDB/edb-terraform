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
  destination_port_range     = each.value.port != null ? each.value.port : "*"
  destination_address_prefixes = each.value.egress_cidrs != null ? each.value.egress_cidrs : var.egress_cidrs
  source_port_range          = "*"
  source_address_prefixes    = each.value.ingress_cidrs != null ? each.value.ingress_cidrs : var.ingress_cidrs
  access                     = "Allow"
  direction                  = "Inbound"
  priority                   = 100 + tonumber(each.key)
}
