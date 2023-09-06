terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.37.0"
    }
    toolbox = {
      source = "bryan-bar/toolbox"
      version = "~> 0.1.4"
    }
  }
  required_version = ">= 1.3.6"
}
