variable "security_group_name" {}
variable "resource_name" {}
variable "region" {}
variable "ports" {
    type = list
}
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
variable "name_id" {
    type = string
}
variable "tags" {}
