variable "name" {
  type = string
  default = "default_name"
}
variable "operating_system" {
  description = "operating system and default user"
  type = object({
    sku       = string
    offer     = string
    publisher = string
    version   = string
    ssh_user  = string
    ssh_public_key_file = string
    ssh_private_key_file = string
  })
}
variable "machine" {
  description = "cloud resources needed"
  type = object({
    type          = string
    region        = string
    zone          = optional(string)
    instance_type = string
    ssh_port      = optional(number, 22)
    volume = object({
      caching = optional(string, "None")
      size_gb = number
      type    = string
    })
  })
}
variable "ports" {
  type = list
  default = []
  nullable = false
}
variable "tags" {
  type    = map(string)
  default = {}
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
variable "security_group_name" {}
variable "security_group_id" {}
variable "private_key" {}
variable "public_key" {}
variable "use_agent" {
  default = false
}
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
  additional_volumes_length = length(var.additional_volumes)
  additional_volumes_count = local.additional_volumes_length > 0 ? 1 : 0
  additional_volumes_map = { for i, v in var.additional_volumes : i => v }

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
  # device name start: /dev/sdc
  prefix = "/dev/"
  base = ["sd"]
  letters = [
    "c", "d", "e", "f", 
    "g", "h", "i", "j", 
    "k", "l", "m", "n",
    "o", "p", "q", "r"
  ]
  # List(List(String))
  # [[ "/dev/sdc" ], ]
  linux_device_names = [
    for letter in local.letters:
      formatlist("${local.prefix}%s${letter}", local.base)
  ]
  # List(String) with comma delimiter
  # [ "/dev/sdc" , ]
  string_device_names = [
    for names in local.linux_device_names:
      format("%s", names...)
  ]
}
