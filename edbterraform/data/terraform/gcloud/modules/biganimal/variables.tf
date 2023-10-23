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
      Please choose from the following: single, ha
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
variable "password" {}

variable "publicly_accessible" {
  type     = bool
  default  = true
  nullable = false
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
  instance_type = !startswith("gcp:", var.instance_type) ? format("gcp:%s",var.instance_type) : var.instance_type

  volume_size = "${var.volume.size_gb} Gi"

  cloud_provider = var.cloud_account ? "gcp" : "bah:gcp"
  cluster_name = format("%s-%s", var.name, var.name_id)
}
