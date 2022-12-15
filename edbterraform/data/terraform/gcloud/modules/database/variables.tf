variable "name" {}
variable "network" {}
variable "region" {
  type    = string
  default = null
}
variable "zone" {
  type    = string
  default = null
}
variable "autoresize" {
  type    = bool
  default = false
}
variable "autoresize_limit" {
  type    = number
  default = 1
}
variable "instance_type" {
  type    = string
  default = "db-f1-micro"
}
variable "engine" {
  type    = string
  default = "postgres"
}
variable "engine_version" {
  type    = string
  default = 14
}
variable "disk_size" {
  type    = number
  default = 25
}
variable "disk_type" {
  type    = string
  default = "PD_SSD"
}
variable "dbname" {
  type    = string
  default = "dbname_default"
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
  type    = number
  default = 5432
}
variable "settings" {
  type = list(object({
    name  = string
    value = string
  }))
  default = null
}
variable "deletion_protection" {
  type    = bool
  default = false
}
variable "google_service_url" {
  type    = string
  default = "servicenetworking.googleapis.com"
}
