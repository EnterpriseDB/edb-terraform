resource "azurerm_ssh_public_key" "main" {
  name                = var.name
  resource_group_name = var.resource_name
  location            = var.region
  public_key          = var.public_key
}
