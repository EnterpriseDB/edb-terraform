variable "ssh_pub_key" {}
variable "key_name" {}
variable "name_id" { default = "0" }
variable "tags" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

resource "aws_key_pair" "key_pair" {
  key_name   = "${var.key_name}-${var.name_id}"
  public_key = var.ssh_pub_key
  tags       = var.tags
}
