variable "network_name" {}
variable "name_id" {}
variable "region" {}
variable "ports" {}
variable "public_cidrblocks" {
  type = list(string)
  default = ["0.0.0.0/0"]
  nullable = false
}
variable "internal_cidrblocks" {
  type = list(string)
  default = []
  nullable = false
}
variable "service_cidrblocks" {
  type = list(string)
  default = ["0.0.0.0/0"]
  nullable = false
}
