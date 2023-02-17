variable "network_name" {}
variable "name_id" {}
variable "region" {}
variable "ports" {}
variable "ingress_cidrs" {
  type = list(string)
}
variable "egress_cidrs" {
  type = list(string)
}
