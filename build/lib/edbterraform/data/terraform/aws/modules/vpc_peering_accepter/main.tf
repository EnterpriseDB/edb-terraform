variable "connection_id" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
  }
}

resource "aws_vpc_peering_connection_accepter" "main" {
  vpc_peering_connection_id = var.connection_id
  auto_accept               = true
}
