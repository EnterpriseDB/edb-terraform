variable "publisher" {}
variable "offer" {}
variable "plan" {}

resource "azurerm_marketplace_agreement" "image" {
  publisher = var.publisher
  offer     = var.offer
  plan      = var.plan
}

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 3.37.0"
    }
  }
  required_version = ">= 0.13"
}
