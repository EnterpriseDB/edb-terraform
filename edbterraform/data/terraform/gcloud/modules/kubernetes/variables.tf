variable "machine" {}
variable "region" {}
variable "cluster_name" {}
variable "subnetwork" {}
variable "network" {}
variable "name_id" { default = "0" }
variable "tags" {
  type    = map(string)
  default = {}
}
