variable "vpc_id" {}
variable "peer_vpc_id" {}
variable "peer_region" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
  }
}

resource "aws_vpc_peering_connection" "main" {
  vpc_id        = var.vpc_id
  peer_vpc_id   = var.peer_vpc_id
  peer_region   = var.peer_region
  auto_accept   = false
}
