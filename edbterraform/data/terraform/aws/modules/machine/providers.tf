terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
    toolbox = {
      source  = "bryan-bar/toolbox"
    }
  }
}
