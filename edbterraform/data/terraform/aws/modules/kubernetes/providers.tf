terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
  required_version = ">= 1.3.6"
}
