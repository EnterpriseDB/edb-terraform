resource "azurerm_resource_group" "main" {
  name     = var.name
  location = var.region
  tags     = var.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vpc-${var.name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.cidr_blocks
  tags                = var.tags

  depends_on = [azurerm_resource_group.main]
}
