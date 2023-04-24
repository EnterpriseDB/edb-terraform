variable "engine" {
}
variable "engine_version" { 
}
variable "instance_type" {
}
variable "settings" {
}
variable "cluster_name" {
}
variable "name" {
  type = string
}
variable "resource_name" {
  type = string
}
variable "dbname" {
  type = string
  default = ""
  nullable = false
}
variable "region" {
}
variable "zone" {
  type     = string
  default  = null
  nullable = true

  validation {
    condition = (
      # try(..., false) must be used since var.location.zone might be null,
      # null is not allowed in contains() function and fails during terraform plan
      var.zone == null ||
      try(contains(["1", "2", "3", ], var.zone), false)
    )
    error_message = <<-EOT
    Zone must be: null, 1 - 3
    EOT
  }
}
variable "tags" {
}
variable "name_id" {
}
variable "username" {
}
variable "password" {
}
variable "public_access" {
  type = bool
  default = false
}
/*
  sizes_mb = [
    32768,
    65536,
    131072,
    262144,
    524288,
    1048576,
    2097152,
    4194304,
    8388608,
    16777216,
*/
variable "size_gb" {
  type = number
  default = 0
}
locals {
  size_mb = var.size_gb * 1024
}
