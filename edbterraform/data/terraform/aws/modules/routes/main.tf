variable "cluster_name" {}
variable "subnet_count" {}
variable "vpc_id" {}
variable "project_tag" {}
variable "public_cidrblock" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
  }
}

data "aws_subnets" "ids" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = var.vpc_id

  tags = {
    Name = format("%s_%s_%s", var.project_tag, var.cluster_name, "igw")
  }
}

resource "aws_route_table" "custom_route_table" {
  vpc_id = var.vpc_id

  route {
    // Associated subnet can reach everywhere, if set to 0.0.0.0
    cidr_block = var.public_cidrblock
    // Used to reach out to Internet
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = format("%s_%s_%s", var.project_tag, var.cluster_name, "route_table")
  }
}

resource "aws_route_table_association" "rt_associations" {
  count          = var.subnet_count
  subnet_id      = element(tolist(data.aws_subnets.ids.ids), count.index)
  route_table_id = aws_route_table.custom_route_table.id
}
