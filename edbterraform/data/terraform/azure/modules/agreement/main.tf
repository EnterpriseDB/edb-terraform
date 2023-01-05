resource "azurerm_marketplace_agreement" "image" {
  publisher = var.publisher
  offer     = var.offer
  plan      = var.plan
}
