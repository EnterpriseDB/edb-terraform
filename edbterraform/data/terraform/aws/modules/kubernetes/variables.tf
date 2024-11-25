variable "region" {
  default = "us-east-1"
}

variable "name" {
  default = "K8s-Default-Name"
  nullable = false
}

variable "name_id" {
  type     = string
  default  = null
  nullable = true
}

locals {
  name = var.name_id != null && var.name_id != "" ? "${var.name}-${var.name_id}" : var.name
  vpc_name = format("eks-%s", local.name)
}

variable "clusterVersion" {
  default = "1.24"
}

variable "desiredCapacity" {
  default = 3
}

variable "maxCapacity" {
  default = 3
}

variable "minCapacity" {
  default = 1
}

variable "instanceType" {
  default = "c6a.xlarge"
}

variable "vpcCidr" {
  default = "172.16.0.0/16"
}

variable "privateSubnet1" {
  default = "172.16.1.0/24"
}

variable "privateSubnet2" {
  default = "172.16.2.0/24"
}

variable "privateSubnet3" {
  default = "172.16.3.0/24"
}

variable "publicSubnet1" {
  default = "172.16.4.0/24"
}

variable "publicSubnet2" {
  default = "172.16.5.0/24"
}

variable "publicSubnet3" {
  default = "172.16.6.0/24"
}

variable "tags" {
  default = {}
}
