variable "name" {
  type     = string
  default  = "instance-name"
  nullable = false
}
variable "network" {
  type    = string
  default = null
}
variable "region" {
  type    = string
  default = null
}
variable "zone" {
  type     = string
  nullable = false
}
variable "public_access" {
  type     = bool
  default  = false
  nullable = false
}
variable "autoresize" {
  type     = bool
  default  = false
  nullable = false
}
variable "autoresize_limit" {
  type     = number
  default  = 1
  nullable = false
}
variable "instance_type" {
  type     = string
  default  = "db-f1-micro"
  nullable = false
}
variable "engine" {
  type     = string
  default  = "postgres"
  nullable = false
}
variable "engine_version" {
  type     = string
  default  = 14
  nullable = false
}
variable "disk_size" {
  type     = number
  default  = 25
  nullable = false
}
variable "disk_type" {
  type     = string
  default  = "PD_SSD"
  nullable = false
}
variable "dbname" {
  type     = string
  default  = "dbname_default"
  nullable = false
}
variable "username" {
  type    = string
  default = "postgres"
}
variable "password" {
  type      = string
  sensitive = true
  default   = null
}
variable "port" {
  type     = number
  default  = 5432
  nullable = false
}
variable "settings" {
  type = list(object({
    name  = string
    value = string
  }))
  default = null
}
variable "deletion_protection" {
  type     = bool
  default  = false
  nullable = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
locals {
  # gcloud label restrictions:
  # - lowercase letters, numeric characters, underscores and dashes
  # - 63 characters max
  # to match other providers as close as possible,
  # we will do any needed handling and continue to treat
  # key-values as tags even though they are labels under gcloud
  labels = { for key,value in var.tags: key => lower(replace(value, ":", "_"))}
}
