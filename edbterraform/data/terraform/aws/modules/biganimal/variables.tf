variable "project" {
  type = object({
    id = optional(string)
  })
}

variable "name" {}
variable "name_id" {}
variable "cloud_account" {
  type = bool
  default = true
  nullable = false
  description = "Option for selecting if biganimal should host the resources with your own cloud account instead of biganimal hosted resources"
}
variable "cluster_name" {}
variable "cluster_type" {
  type = string
  default = "single"

  validation {
    condition = contains(["single", "ha"], var.cluster_type)
    error_message = (
      <<-EOT
      ${var.cluster_type} not a valid option.
      Please choose from the following: single, ha, eha
      EOT
    )
  }
}
variable "region" {}
variable "node_count" {}
variable "instance_type" {}
variable "engine" {
  type = string
  default = "epas"

  validation {
    condition = contains(["epas", "pgextended", "postgres"], var.engine)
    error_message = (
      <<-EOT
      ${var.engine} not a valid option.
      Please choose from the following: epas, pgextended, postgres
      EOT
    )
  }
}
variable "engine_version" {
  type = number
}
variable "settings" {}
variable "volume" {}
variable "wal_volume" {}
variable "password" {}

variable "publicly_accessible" {
  type     = bool
  default  = true
  nullable = false
}

variable "cidr_range" {
  description = "BigAnimal ip range is pre-set and cannot be updated"
  type = string
  default = "10.0.0.0/16"
  validation {
    condition = var.cidr_range == "10.0.0.0/16"
    error_message = "BigAnimal ip range is pre-set and cannot be updated"
  }
}

variable "allowed_ip_ranges" {
  type = list(object({
    cidr_block = string
    description = optional(string)
  }))
  nullable = false
  default = []
}

variable "tags" {
  type = map(any)
  default = {}
  nullable = false
}

locals {
  # resource expects a cloud provider prefix infront of its instance type
  instance_type = !startswith("aws:", var.instance_type) ? format("aws:%s",var.instance_type) : var.instance_type

  volume_size = "${var.volume.size_gb} Gi"
  wal_volume_size = "${var.wal_volume.size_gb} Gi"

  cloud_provider = var.cloud_account ? "aws" : "bah:aws"
  cluster_name = format("%s-%s", var.name, var.name_id)
}
