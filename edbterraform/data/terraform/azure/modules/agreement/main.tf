data "azurerm_marketplace_agreement" "reference" {
  count = var.accept ? 0 : 1

  publisher = var.publisher
  offer     = var.offer
  plan      = var.plan
}

resource "azurerm_marketplace_agreement" "agreement" {
  count = var.accept ? 1 : 0

  publisher = var.publisher
  offer     = var.offer
  plan      = var.plan
}
