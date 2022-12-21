terraform {
  required_providers {
    google = {
      source = "hashicorp/google-beta"
      version = ">= 4.46.0"
    }
  }
  required_version = ">= 0.13"
}
