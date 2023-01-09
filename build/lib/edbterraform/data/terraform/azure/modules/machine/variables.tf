variable "operating_system" {
  type = object({
    sku       = string
    offer     = string
    publisher = string
    version   = string
  })
}
variable "machine" {
  type = object({
    name          = string
    type          = string
    region        = string
    zone          = optional(string)
    instance_type = string
    volume = object({
      caching = optional(string, "None")
      size_gb = number
      type    = string
    })
  })
}
variable "cluster_name" {}
locals {
  zones         = var.machine.zone == null ? null : [var.machine.zone]
  public_ip_sku = var.machine.zone == null ? "Basic" : "Standard"
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
variable "additional_volumes" {
  type = list(object({
    mount_point = string
    size_gb     = number
    type        = string
    caching     = optional(string, "None")
    iops        = optional(number)
  }))

  validation {
    condition = alltrue([
      for volume in var.additional_volumes :
      volume.iops == null ||
      contains(["UltraSSD_LRS", "PremiumV2_LRS", ], volume.type)
    ])
    error_message = <<-EOT
    IOPs is only configurable with the following disk types:
    UltraSSD PremiumV2
    EOT
  }

  validation {
    condition = alltrue([
      for volume in var.additional_volumes :
      volume.caching == "None" ||
      volume.type != "UltraSSD_LRS"
    ])
    error_message = <<-EOT
    Caching must be set to "None" when using UltraSSD_LRS
    EOT
  }

  default  = []
  nullable = false
}

locals {
  additional_volumes = {
    for key, value in var.additional_volumes :
    key => value
  }

  volume_script_count = length(var.additional_volumes) > 0 ? 1 : 0

  premium_ssd = {
    regions = ["eastus", "westeurope", ]
    value   = "PremiumV2_LRS"
  }

  # Must be enabled in virtual machine resource when in use
  ultra_ssd_enabled = anytrue([
    for volume in var.additional_volumes :
    volume.type == "UltraSSD_LRS"
  ])

  # /dev/sda /dev/sdb are mounted by default
  # azure automatically sets additional mount points starting with /dev/sdc
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
