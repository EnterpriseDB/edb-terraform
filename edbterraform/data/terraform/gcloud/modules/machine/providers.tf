terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    toolbox = {
      source = "bryan-bar/toolbox"
      version = "~> 0.1.4"
    }
  }
  required_version = ">= 1.3.6"
}
