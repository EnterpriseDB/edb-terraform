terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.53.0"
    }
  }
  required_version = ">= 1.3.6"
}
