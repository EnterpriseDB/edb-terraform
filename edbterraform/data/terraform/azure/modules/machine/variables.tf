/* Variables */
variable "operating_system" {}
variable "machine" {}
variable "cluster_name" {}
variable "location" {
  type = object({
    region = string
    zone = optional(string)
  })
  
  validation {
    condition = (
      var.location.zone == null ||
      contains([
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
      ], var.location.region)
    )
    error_message = <<-EOT
    Regions with zones are restricted due to limited availability.
    Allowed regions can be seen inside of variables.tf validation or change zone to 0.
    For up-to-date regions with available zone support, please visit:
    https://learn.microsoft.com/en-us/azure/reliability/availability-zones-service-support#azure-regions-with-availability-zone-support
    EOT
  }

  validation {
    condition = (
      # try(..., false) must be used since var.location.zone might be null,
      # null is not allowed in contains() function and fails during terraform plan
      var.location.zone == null ||
      try(contains(["1","2","3",], var.location.zone), false)
    )
    error_message = <<-EOT
    Zone must be: 1 - 3
    EOT
  }
}

locals {
  zones = var.location.zone == null ? null : [ var.location.zone ]
  sku = var.location.zone == null ? "Basic" : "Standard"
}

variable "resource_name" {
  type = string
}
variable "name_id" {
  type = string
}
variable "subnet_id" {}
variable "ssh_user" {}
variable "public_key_name" {}
variable "private_key" {}
variable "caching" {
  type = string
  default = "ReadWrite"
  nullable = false
}
variable "additional_volumes" {
  type = list(object({
    mount_point = string
    size_gb     = number
    type        = string
    iops        = optional(number)
  }))

  validation {
    condition = alltrue([
      for volume in var.additional_volumes:
        volume.iops == null ||
        contains(["UltraSSD", "PremiumV2",], volume.type)
    ])
    error_message = <<-EOT
    IOPs is only configurable with the following disk types:
    UltraSSD PremiumV2
    EOT
  }

  default = []
  nullable = false
}

locals {
  additional_volumes = { 
    for key, value in var.additional_volumes:
      key => value
  }

  volume_script_count = length(var.additional_volumes) > 0 ? 1 : 0

  linux_device_names = [
    "/dev/sdc",
    "/dev/sdd",
    "/dev/sde",
    "/dev/sdf",
    "/dev/sdg",
    "/dev/sdh",
    "/dev/sdi",
    "/dev/sdj",
  ]
}
