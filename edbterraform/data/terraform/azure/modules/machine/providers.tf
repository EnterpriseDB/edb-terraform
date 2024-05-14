terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
    toolbox = {
      source = "bryan-bar/toolbox"
    }
  }
  required_version = ">= 1.3.6"
}
