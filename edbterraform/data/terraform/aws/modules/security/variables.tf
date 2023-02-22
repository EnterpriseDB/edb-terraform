variable "vpc_id" {}
variable "project_tag" {}
variable "ports" {}
variable "cluster_name" {}
variable "ingress_cidrs" {
  type = list(string)
  default = [ "0.0.0.0/0" ]
}
variable "egress_cidrs" {
  type = list(string)
  default = [ "0.0.0.0/0" ]
}
