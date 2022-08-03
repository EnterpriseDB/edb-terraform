variable "ssh_pub_key" {}
variable "cluster_name" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
  }
}

resource "aws_key_pair" "key_pair" {
  key_name   = var.cluster_name
  public_key = file(var.ssh_pub_key)
}
