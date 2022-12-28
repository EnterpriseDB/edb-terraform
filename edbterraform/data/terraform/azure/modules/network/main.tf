resource "azurerm_subnet" "internal" {
  name = var.name
  resource_group_name = var.resource_name
  virtual_network_name = var.network_name
  address_prefixes = var.ip_cidr_range
}
