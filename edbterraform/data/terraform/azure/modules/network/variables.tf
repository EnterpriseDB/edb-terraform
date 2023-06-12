variable "name" {
  type     = string
  default  = "name"
  nullable = false
}
variable "resource_name" {
  type     = string
  default  = "resource"
  nullable = false
}
variable "network_name" {
  type     = string
  default  = "network"
  nullable = false
}
variable "ip_cidr_range" {
  type        = list(string)
  default     = []
  description = <<-EOT
  From Terraform
  NOTE: Currently only a single address prefix can be set 
  as the Multiple Subnet Address Prefixes Feature 
  is not yet in public preview or general availability.
  EOT
  nullable    = false
}
variable "region" {
  type = string
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
  type = map(string)
  default = {}
  nullable = false
}
variable "name_id" {
  default = 0
}
locals {
  regions_with_zones = [
    # Americas
    "brazilsouth",
    "canadacentral",
    "centralus",
    "eastus",
    "eastus2",
    "southcentralus",
    # US Gov Virginia not available
    "westus2",
    "westus3",
    # Europe
    "francecentral",
    "germanywestcentral",
    "northeurope",
    "norwayeast",
    "uksouth",
    "westeurope",
    "swedencentral",
    "switzerlandnorth",
    # Middle East
    "qatarcentral",
    "uaenorth",
    # Africa
    "southafricanorth",
    # Asia Pacific
    "australiaeast",
    "centralindia",
    "japaneast",
    "koreacentral",
    "southeastasia",
    # China North 3 not available
    "eastasia",
  ]
}
