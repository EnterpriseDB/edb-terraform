resource "azurerm_subnet" "internal" {
  name                 = var.name
  resource_group_name  = var.resource_name
  virtual_network_name = var.network_name
  address_prefixes     = var.ip_cidr_range

  lifecycle {
    precondition {
      condition = (
        var.zone == null ||
        contains(local.regions_with_zones, var.region)
      )
      error_message = <<-EOT
      Regions with zones are restricted due to limited availability.
      Change zone to 0 or select a region with zones: ${jsonencode(local.regions_with_zones)}
      For up-to-date regions with available zone support, please visit:
      https://learn.microsoft.com/en-us/azure/reliability/availability-zones-service-support#azure-regions-with-availability-zone-support
      EOT
    }
  }
}

resource "azurerm_network_security_group" "firewall" {
  name                = replace(join("-", formatlist("%#v", [var.name, var.region, var.zone, var.name_id])), "\"", "")
  resource_group_name = var.resource_name
  location            = var.region
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "firewall" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.firewall.id
}
