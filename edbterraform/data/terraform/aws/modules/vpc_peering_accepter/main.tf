variable "connection_id" {}
variable "tags" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

resource "aws_vpc_peering_connection_accepter" "main" {
  vpc_peering_connection_id = var.connection_id
  auto_accept               = true
  tags                      = var.tags
}
