variable data_groups {
  type = map(object({
    type           = string
    region         = string
    node_count     = number
    engine         = string
    engine_version = number
    instance_type  = string
    volume = object({
      size_gb   = number
      type      = string
      properties = string
      iops      = optional(number)
      throughput = optional(number)
    })
    wal_volume = optional(object({
      size_gb   = number
      type      = string
      properties = string
      iops      = optional(number)
      throughput = optional(number)
    }))
    pgvector       = optional(bool, false)
    settings = optional(list(object({
      name  = string
      value = string
    })), [])
    allowed_ip_ranges = optional(list(object({
      cidr_block = string
      description = optional(string, "default description")
    })), [])
    allowed_machines = optional(list(string), ["*"])
  }))

  validation {
    condition = !anytrue([for name, grouping in var.data_groups: !contains(["single", "ha", "pgd"], grouping.type)])
    error_message = (
      <<-EOT
      Data groups must define a valid type.
      Please choose from the following: single, ha, pgd
      Data groups: ${jsonencode(var.data_groups)}
      EOT
    )
  }

  validation {
    condition = !anytrue([for name, grouping in var.data_groups: !contains(["epas", "pgextended", "postgres"], grouping.engine)])
    error_message = (
      <<-EOT
      Data groups must define a valid engine.
      Please choose from the following: epas, pgextended, postgres
      Data groups: ${jsonencode(var.data_groups)}
      EOT
    )
  }

  validation {
    condition = length(var.data_groups) >= 1
    error_message = (
      <<-EOT
      Data groups must define at least one data group.
      EOT
    )
  }

  validation {
    condition = length(var.data_groups) <= 1 || !anytrue([for name, grouping in var.data_groups: grouping.type != "pgd"])
    error_message = (
      <<-EOT
      Multiple data groups are only supported for type "pgd".
      EOT
    )
  }

  validation {
    condition = alltrue([for name, grouping in var.data_groups: grouping.type != "pgd" || grouping.volume.size_gb >= 32 || try(grouping.wal_volume.size_gb,32) >= 32])
    error_message = (
      <<-EOT
      When using pgd, the minimum storage size is 32 gb.
      EOT
    )
  }

  validation {
    condition = length(distinct([for k,v in var.data_groups: v.region])) == length([for k,v in var.data_groups: v.region])
    error_message = (
      <<-EOT
      Only one data group allowed per region.
      Regions defined: ${jsonencode([for k,v in var.data_groups: v.region])}
      EOT
    )
  }

  validation {
    condition = length(distinct([for name, grouping in var.data_groups: grouping.type])) <= 1
    error_message = (
      <<-EOT
      All types must match:
      ${jsonencode(var.data_groups)}
      EOT
    )
  }
}

variable "witness_groups" {
  description = "A single witness node is needed when using 2 data groups. It can be in a different cloud provider but cannot be in the same region as the data groups when using the same provider."
  default = {}
  nullable = false
  type = map(object({
    region = string
    cloud_service_provider = string
    maintenance_window = optional(object({
      is_enabled = bool
      start_day = number
      start_time = string
    }), {
      is_enabled = false
      start_day = 0
      start_time = "00:00"
    })
  }))

  validation {
    condition = (
      var.witness_groups == {} ||
      var.witness_groups == null ||
      alltrue([for k, v in var.witness_groups: v.maintenance_window.is_enabled == true || v.maintenance_window.start_day == 0 && v.maintenance_window.start_time == "00:00"])
    )
    error_message = (
      <<-EOT
      When maintenance window is disabled, start day and start time must be 0
      # https://github.com/EnterpriseDB/terraform-provider-biganimal/issues/491
      EOT
    )
  }
}

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
variable "password" {
  nullable = true
  sensitive = true
}

resource "random_password" "password" {
  length          = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

locals {
  password = var.password != null && var.password != "" ? var.password : random_password.password.result
}

variable "cloud_provider" {
  type = string
  default = "azure"
  nullable = false
  validation {
    condition = contains(["azure", "bah:azure"], var.cloud_provider)
    error_message = "Invalid cloud provider"
  }
}

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

variable "tags" {
  type = map(any)
  default = {}
  nullable = false
}

locals {
  # superuser not allowed for biganimal-hosted clusters
  superuser_access = var.cloud_account ? true : false

  service_cidrblocks = [
    for cidr in var.service_cidrblocks : {
      cidr_block = cidr
      description = "Service CIDR"
    }
  ]

  use_pgd = anytrue([for group in var.data_groups: group.type == "pgd"]) ? true : false
  use_wal_volume = anytrue([for group in var.data_groups: group.wal_volume != null && group.wal_volume != []]) ? true : false

  data_groups = {
    for name, values in var.data_groups : name => (merge(values, {
      # Private networking blocks setting of allowed_ip_ranges and forces private endpoints or vpc peering to be used.
      # The provider overrides with 0.0.0.0/0 but fails to create if allowed_ip_ranges is not an empty list.
      allowed_ip_ranges = !var.publicly_accessible ? [] : (
        # If cidrblocks are not set, biganimal opens service to all ips.
        # Block traffic if it is an empty list to avoid accidental exposure of the database
        length(values.allowed_ip_ranges) <= 0 && length(var.machine_cidrblocks) <= 0 && length(local.service_cidrblocks) <= 0 ? [{
          cidr_block = "127.0.0.1/32"
          description = "private default"
        }] : concat(
          values.allowed_ip_ranges,
          local.service_cidrblocks,
          # When wildcards are used, we allow all machine_cidrblocks
          # Otherwise, only allow the specified machines
          flatten([
            for machine_name in keys(var.machine_cidrblocks): [
              for cidr_block in var.machine_cidrblocks[machine_name]: {
                cidr_block = cidr_block
                description = "Machine CIDR - ${machine_name}"
              }
            ]
            if anytrue([for allow_name in values.allowed_machines: contains(values.allowed_machines, "*") || contains(keys(var.machine_cidrblocks), allow_name)])
          ]),
        )
      )
      # Handle single instance node count since it can only be 1
      node_count = values.type == "single" ? 1 : values.node_count
      # resource expects a cloud provider prefix infront of its instance type
      instance_type = !startswith("${var.cloud_provider}:", values.instance_type) ? format("${var.cloud_provider}:%s", values.instance_type) : values.instance_type
      volume_size = "${values.volume.size_gb} Gi"
      # resource expects a cloud provider prefix infront of volume type when using premiumstorage
      volume_type = !startswith("${var.cloud_provider}", var.volume.type) && endswith("premiumstorage", var.volume.type) ? format("${var.cloud_provider}%s", var.volume.type) : var.volume.type
    }))
  }

}


locals {

  cloud_provider = var.cloud_account ? var.cloud_provider : "bah:${var.cloud_provider}"
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
  API_DATA = concat([
    for group_name, group_values in var.data_groups: {
      clusterName = local.cluster_name
      clusterType = group_values.type
      password = local.password
      instanceType = { instanceTypeId = group_values.instance_type }
      allowedIpRanges = [
        for key, value in group_values.allowed_ip_ranges :
          {
            cidrBlock = value.cidr_block
            description = value.description
          }
      ]
      storage = {
        for key, value in group_values.volume : local.TERRAFORM_API_MAPPING[key] =>
          key == "size_gb" ? "${value} Gi" : tostring(value) if value != null
      }
      walStorage = {
        for key, value in group_values.wal_volume == null ? {} : group_values.wal_volume : local.TERRAFORM_API_MAPPING[key] =>
          key == "size_gb" ? "${value} Gi" : tostring(value) if value != null
      }
      # required 
      provider = { cloudProviderId = local.cloud_provider }
      clusterArchitecture = {
          clusterArchitectureId = group_values.type
          nodes = group_values.type == "single" ? 1 : group_values.node_count
      }
      region = { regionId = group_values.region }
      pgVersion = { pgVersionId = tostring(group_values.engine_version) }
      pgType = { pgTypeId = group_values.engine }
      pgConfig = group_values.settings
      privateNetworking = !var.publicly_accessible
      backupRetentionPeriod = "1d"
      cspAuth = false
      readOnlyConnections = false
      superuserAccess = true
    }], [{ # PGD configuration
    clusterName = local.cluster_name
    clusterType = one(distinct([for group_name, group_values in var.data_groups: group_values.type]))
    password = local.password
    groups = [ for group_name, group_values in local.data_groups: {
        clusterType = "data_group"
        instanceType = { instanceTypeId = group_values.instance_type }
        allowedIpRanges = [
          for key, value in group_values.allowed_ip_ranges :
            {
              cidrBlock = value.cidr_block
              description = value.description
            }
        ]
        storage = {
          for key, value in group_values.volume : local.TERRAFORM_API_MAPPING[key] =>
            key == "size_gb" ? "${value} Gi" : tostring(value) if value != null
        }
        walStorage = {
          for key, value in group_values.wal_volume == null ? {} : group_values.wal_volume : local.TERRAFORM_API_MAPPING[key] =>
            key == "size_gb" ? "${value} Gi" : tostring(value) if value != null
        }
        # required 
        provider = { cloudProviderId = local.cloud_provider }
        clusterArchitecture = {
            clusterArchitectureId = group_values.type
            nodes = group_values.type == "single" ? 1 : group_values.node_count
        }
        region = { regionId = group_values.region }
        pgVersion = { pgVersionId = tostring(group_values.engine_version) }
        pgType = { pgTypeId = group_values.engine }
        pgConfig = group_values.settings
        privateNetworking = !var.publicly_accessible
        backupRetentionPeriod = "1d"
        cspAuth = false
        readOnlyConnections = false
        superuserAccess = local.superuser_access
      }
    ]}
  # Ternary requires consistent types.
  # A workaround is to setup a list of objects and then use a conditional to choose the correct index.
  ])[local.use_pgd ? 1 : 0]
}
