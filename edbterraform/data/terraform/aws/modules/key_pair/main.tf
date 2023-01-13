variable "ssh_pub_key" {}
variable "key_name" {}
variable "name_id" { default = "0" }

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
  }
}

resource "aws_key_pair" "key_pair" {
  key_name   = "${var.key_name}-${var.name_id}"
  public_key = file(var.ssh_pub_key)
}
