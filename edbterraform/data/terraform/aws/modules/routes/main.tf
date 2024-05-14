variable "cluster_name" {}
variable "subnet_count" {}
variable "vpc_id" {}
variable "public_cidrblock" {}
variable "tags" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
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

  tags = merge({
    Name = format("%s_%s", var.cluster_name, "igw")
  }, var.tags)
}

# Do not define routes in the table.
# Use the aws_route resource otherwise it will flip between creating and destroying.
# Ref: https://github.com/hashicorp/terraform-provider-aws/issues/4110
resource "aws_route_table" "custom_route_table" {
  vpc_id = var.vpc_id

  tags = merge({
    Name = format("%s_%s", var.cluster_name, "route_table")
  }, var.tags)
}

resource "aws_route" "anywhere" {
  route_table_id            = aws_route_table.custom_route_table.id
  // Associated subnet can reach everywhere, if set to 0.0.0.0
  destination_cidr_block    = var.public_cidrblock
  // Used to reach out to Internet
  gateway_id                = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "rt_associations" {
  count          = var.subnet_count
  subnet_id      = element(tolist(data.aws_subnets.ids.ids), count.index)
  route_table_id = aws_route_table.custom_route_table.id
}
