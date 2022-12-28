variable "subnet_id" {}
variable "resource_name" {}
variable "region" {}
variable "service_name" {}
variable "service_ports" {}
variable "region_name" {}
variable "public_cidrblock" {}
variable "region_ports" {}
variable "region_cidrblocks" {}

resource "azurerm_network_security_group" "firewall" {
  name    = var.service_name
  resource_group_name = var.resource_name
  location = var.region
}

resource "azurerm_network_security_rule" "services" {
  count = length(var.service_ports)
  
  resource_group_name = var.resource_name
  network_security_group_name = azurerm_network_security_group.firewall.name

  name = try(var.service_ports[count.index].name, "none")
  description = var.service_ports[count.index].description
  protocol = var.service_ports[count.index].protocol
  destination_port_range = length(tostring(try(var.service_ports[count.index].port, ""))) > 0 ? var.service_ports[count.index].port : "*"
  destination_address_prefix = "*"
  source_port_range = "*"
  source_address_prefix = "*"
  access = "Allow"
  direction = "Inbound"
  priority = 100 + count.index
}

resource "azurerm_network_security_rule" "regions" {
  count = length(var.region_ports)
  
  resource_group_name = var.resource_name
  network_security_group_name = azurerm_network_security_group.firewall.name

  name = try(var.region_ports[count.index].name, "none")
  description = var.region_ports[count.index].description
  protocol = var.region_ports[count.index].protocol
  destination_port_range = length(tostring(try(var.region_ports[count.index].port, ""))) > 0 ? var.region_ports[count.index].port : "*"
  destination_address_prefixes = var.region_cidrblocks
  source_port_range = "*"
  source_address_prefixes = var.region_cidrblocks
  access = "Allow"
  direction = "Inbound"
  priority = 200 + count.index
}

resource "azurerm_subnet_network_security_group_association" "firewall" {
    count = length(try(var.service_ports, var.region_ports, [])) > 0 ? 1 : 0
    
    subnet_id = var.subnet_id
    network_security_group_id = azurerm_network_security_group.firewall.id

    depends_on = [
      azurerm_network_security_group.firewall
    ]
}
