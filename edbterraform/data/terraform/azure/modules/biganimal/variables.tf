variable "project" {
  type = object({
    id = optional(string)
  })
}

variable "pgvector" {
  type = bool
  default = false
  nullable = false
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
    condition = contains(["single", "ha", "pgd"], var.cluster_type)
    error_message = (
      <<-EOT
      ${var.cluster_type} not a valid option.
      Please choose from the following: single, ha, pgd
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

variable "allowed_machines" {
  type = list(string)
  nullable = false
  default = ["*"]
}

variable "machine_cidrblocks" {
  type = map(list(string))
  default = {}
  nullable = false
}

variable "service_cidrblocks" {
  description = "Default cidr blocks for service ports"
  type = list(string)
  nullable = false
  default = []
}

locals {
  # If cidrblocks are not set, biganimal opens service to all ips.
  # Block traffic if it is an empty list to avoid accidental exposure of the database
  mod_ip_ranges = length(var.allowed_ip_ranges) >= 1 ? var.allowed_ip_ranges : [{
    cidr_block = "127.0.0.1/32"
    description = "private default"
  }]
  service_cidrblocks = [
    for cidr in var.service_cidrblocks : {
      cidr_block = cidr
      description = "Service CIDR"
    }
  ]
  machine_cidrblock_wildcard = anytrue([for machine in var.allowed_machines : machine == "*"])
  machine_names = local.machine_cidrblock_wildcard ? [for machine in keys(var.machine_cidrblocks) : machine] : var.allowed_machines
  machine_cidrblocks = flatten([
    for machine_name in local.machine_names : flatten([
      for cidr in var.machine_cidrblocks[machine_name] : {
          cidr_block = cidr
          description = "Machine CIDR - ${machine_name}"
        }
    ])
  ])
  # Private networking blocks setting of allowed_ip_ranges and forces private endpoints or vpc peering to be used.
  # The provider overrides with 0.0.0.0/0 but fails to create if allowed_ip_ranges is not an empty list.
  allowed_ip_ranges = var.publicly_accessible ? concat(local.mod_ip_ranges, local.service_cidrblocks, local.machine_cidrblocks) : []
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
      for key, value in local.allowed_ip_ranges :
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
