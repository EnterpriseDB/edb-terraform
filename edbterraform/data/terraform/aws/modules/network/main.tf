variable "vpc_id" {}
variable "cidr_block" {}
variable "availability_zone" {}
variable "tags" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

resource "aws_subnet" "public_subnets" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.cidr_block
  map_public_ip_on_launch = "true" // Makes the subnet public
  availability_zone       = var.availability_zone

  tags = merge({
    Name = format("%s_%s", var.availability_zone, var.cidr_block)
  }, var.tags)
}

output "subnet_id" {
  value = aws_subnet.public_subnets.id
}
