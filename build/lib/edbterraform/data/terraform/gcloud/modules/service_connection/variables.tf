variable "name" {}
variable "network" {}
variable "google_service_url" {
  type     = string
  default  = "servicenetworking.googleapis.com"
  nullable = false
}
