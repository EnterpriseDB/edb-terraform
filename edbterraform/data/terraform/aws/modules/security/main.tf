variable "vpc_id" {}
variable "public_cidrblock" {}
variable "project_tag" {}
variable "service_ports" {}
variable "cluster_name" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
  }
}

resource "aws_security_group" "rules" {
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [var.public_cidrblock]
  }

  dynamic "ingress" {
    for_each = var.service_ports
    iterator = service_port
    content {
      from_port = service_port.value.port
      to_port   = service_port.value.port
      protocol  = service_port.value.protocol
      description = service_port.value.description
      // This means, all ip address are allowed !
      // Not recommended for production. 
      // Limit IP Addresses in a Production Environment !
      cidr_blocks = [var.public_cidrblock]
    }
  }

  tags = {
    Name = format("%s_%s_%s", var.project_tag, var.cluster_name, "security_rules")
  }
}
