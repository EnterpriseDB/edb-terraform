terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    toolbox = {
      source  = "bryan-bar/toolbox"
    }
  }
  required_version = ">= 1.3.6"
}