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
