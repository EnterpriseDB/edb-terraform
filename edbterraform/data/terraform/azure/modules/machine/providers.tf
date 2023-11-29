terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.37.0"
    }
    toolbox = {
      source = "bryan-bar/toolbox"
      version = "~> 0.2.2"
    }
  }
  required_version = ">= 1.3.6"
}
