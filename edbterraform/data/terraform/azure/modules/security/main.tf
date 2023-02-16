resource "azurerm_network_security_group" "firewall" {
  name                = var.service_name
  resource_group_name = var.resource_name
  location            = var.region
}

resource "azurerm_network_security_rule" "services" {
  count = length(var.service_ports)

  resource_group_name         = var.resource_name
  network_security_group_name = azurerm_network_security_group.firewall.name

  name                       = var.service_ports[count.index].name
  description                = var.service_ports[count.index].description
  # First letter must be uppercase
  protocol                   = title(var.service_ports[count.index].protocol)
  destination_port_range     = var.service_ports[count.index].port != null ? var.service_ports[count.index].port : "*"
  destination_address_prefix = "*"
  source_port_range          = "*"
  source_address_prefix      = "*"
  access                     = "Allow"
  direction                  = "Inbound"
  priority                   = 100 + count.index
}

resource "azurerm_network_security_rule" "regions" {
  count = length(var.region_ports)

  resource_group_name         = var.resource_name
  network_security_group_name = azurerm_network_security_group.firewall.name

  name                         = var.region_ports[count.index].name
  description                  = var.region_ports[count.index].description
  # First letter must be uppercase
  protocol                     = title(var.region_ports[count.index].protocol)
  destination_port_range       = var.region_ports[count.index].port != null ? var.region_ports[count.index].port : "*"
  destination_address_prefixes = var.region_cidrblocks
  source_port_range            = "*"
  source_address_prefixes      = var.region_cidrblocks
  access                       = "Allow"
  direction                    = "Inbound"
  priority                     = 200 + count.index
}

resource "azurerm_subnet_network_security_group_association" "firewall" {
  count = length(var.service_ports) > 0 || length(var.region_ports) > 0 ? 1 : 0

  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.firewall.id

  depends_on = [
    azurerm_network_security_group.firewall
  ]
}
