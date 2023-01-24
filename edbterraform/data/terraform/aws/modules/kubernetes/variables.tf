variable "region" {
  default = "us-east-1"
}

variable "vpcAndClusterPrefix" {
  default = "EDB-K8s-CNP"
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
