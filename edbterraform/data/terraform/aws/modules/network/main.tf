variable "public_subnet_tag" {}
variable "vpc_id" {}
variable "cidr_block" {}
variable "availability_zone" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
  }
}

resource "aws_subnet" "public_subnets" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.cidr_block
  map_public_ip_on_launch = "true" // Makes the subnet public
  availability_zone       = var.availability_zone

  tags = {
    Name = format("%s_%s_%s", var.public_subnet_tag, var.availability_zone, var.cidr_block)
  }
}
