variable "name" {
    type = string
    default = "name"
    nullable = false
}
variable "resource_name" {
  type = string
  default = "resource"
  nullable = false
}
variable "network_name" {
  type = string
  default = "network"
  nullable = false
}
variable "ip_cidr_range" {
  type = list(string)
  default = []
  description = <<-EOT
  From Terraform
  NOTE: Currently only a single address prefix can be set 
  as the Multiple Subnet Address Prefixes Feature 
  is not yet in public preview or general availability.
  EOT
  nullable = false
}
variable "region" {}
variable "zone" {}
# variable "security_group_ids" {}
