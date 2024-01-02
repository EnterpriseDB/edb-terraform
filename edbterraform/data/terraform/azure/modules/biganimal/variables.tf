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
variable "wal_volume" {
  nullable = false
  default = {}
}
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
  instance_type = !startswith("azure:", var.instance_type) ? format("azure:%s",var.instance_type) : var.instance_type

  # resource expects a cloud provider prefix infront of volume type when using premiumstorage
  volume_type = !startswith("azure", var.volume.type) && endswith("premiumstorage", var.volume.type) ? format("azure%s", var.volume.type) : var.volume.type
  volume_size = "${var.volume.size_gb} Gi"

  cloud_provider = var.cloud_account ? "azure" : "bah:azure"
  cluster_name = format("%s-%s", var.name, var.name_id)

  // Create an object that excludes any null objects
  TERRAFORM_API_MAPPING = {
    iops = "iops"
    throughput = "throughput"
    size_gb = "size"
    properties = "volumePropertiesId"
    type = "volumeTypeId"
  }
  // Remove null values from the volume properties and save with the api variable naming as the key
  // Size must be saved as a string and with the Gi suffix
  API_DATA = {
    clusterName = local.cluster_name
    instanceType = { instanceTypeId = local.instance_type }
    allowedIpRanges = [
      for key, value in var.allowed_ip_ranges :
        {
          cidrBlock = value.cidr_block
          description = value.description
        }
    ]
    # "premiumstorage" requires "azure" as a prefix when calling the api directly
    storage = {
      for key, value in var.volume : local.TERRAFORM_API_MAPPING[key] =>
        key == "size_gb" ? "${value} Gi"
        : contains(["type"], key) && contains(["premiumstorage"], value) ? "azurepremiumstorage"
        : tostring(value) if value != null
    }
    walStorage = {
      for key, value in var.wal_volume : local.TERRAFORM_API_MAPPING[key] =>
        key == "size_gb" ? "${value} Gi"
        : contains(["type"], key) && contains(["premiumstorage"], value) ? "azurepremiumstorage"
        : tostring(value) if value != null
    }
    # required 
    provider = { cloudProviderId = local.cloud_provider }
    clusterArchitecture = {
        clusterArchitectureId = var.cluster_type
        nodes = var.node_count
    }
    region = { regionId = var.region }
    pgVersion = { pgVersionId = tostring(var.engine_version) }
    pgType = { pgTypeId = var.engine }
    pgConfig = var.settings
    password = var.password
    privateNetworking = !var.publicly_accessible
    backupRetentionPeriod = "1d"
    cspAuth = false
    readOnlyConnections = false
    superuserAccess = true
  }
}
