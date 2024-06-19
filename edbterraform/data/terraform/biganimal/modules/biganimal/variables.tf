variable data_groups {
  type = map(object({
    cloud_account  = optional(bool, true)
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

  validation {
    condition = alltrue([for name, grouping in var.data_groups: grouping.type != "pgd" || grouping.node_count == 2 || grouping.node_count == 3])
    error_message = (
      <<-EOT
      When using pgd, node_count must be 2 or 3.
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
    cloud_account  = optional(bool, true)
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
    id = optional(string, "")
  })
  nullable = false
}

# Check if the credentials and uri are valid by accessing the BigAnimal API
data "biganimal_projects" "projects" {
  query = ""
}

# Check for a valid project id and uri
# This will be deferred to 'apply' when creating a new project
data "biganimal_region" "regions" {
  cloud_provider = var.cloud_provider
  project_id = var.project.id
}

# This will be deferred to 'apply' when creating a new project
data "external" "ba_api_access" {
  query = {
    depends0 = can(data.biganimal_projects.projects)
    depends1 = can(data.biganimal_region.regions)
  }
  program = [
    "bash",
    "-c",
    <<EOT
    set -eou pipefail

    # Get json object from stdin
    IFS='' read -r input || [ -n "$input" ]

    # Check if the access key or bearer token is set as an environment variable
    #   for access within scripts and to avoid credentials within provider configurations
    if [ -z "$${BA_ACCESS_KEY:+''}" ] && [ -z "$${BA_BEARER_TOKEN:+''}" ]
    then
      printf "\n%s\n" "Error: BigAnimal API access keys are not defined in the environment. Please set BA_ACCESS_KEY or BA_BEARER_TOKEN." 1>&2
      exit 1
    fi

    # Set auth header
    AUTH_HEADER=""
    if [ ! -z "$${BA_ACCESS_KEY:+''}" ]
    then
      AUTH_HEADER="x-access-key: $BA_ACCESS_KEY"
    else
      AUTH_HEADER="authorization: Bearer $BA_BEARER_TOKEN"
    fi

    # Check for a valid project id, uri, and access to the endpoint
    URI="$${BA_API_URI:=https://portal.biganimal.com/api/v3/}"
    PROJECT_ID="${var.project.id}"
    ENDPOINT="projects/$PROJECT_ID/cloud-providers"
    REQUEST_TYPE="GET"
    if ! RESPONSE=$(curl --silent --show-error --fail-with-body --location --request $REQUEST_TYPE --header "content-type: application/json" --header "$AUTH_HEADER" --url "$URI$ENDPOINT" 2>&1) || \
       ! RESULT=$(printf "$RESPONSE" | jq -er .data | jq -er tostring 2>&1)
    then
      RC="$${PIPESTATUS[0]}"
      printf "ERROR: Invalid response\n" 1>&2
      printf "%s: %s\n" "URI" "$URI" 1>&2
      printf "%s: %s\n" "ENDPOINT" "$ENDPOINT" 1>&2
      printf "%s: %s\n" "PROJECT_ID" "$PROJECT_ID" 1>&2
      printf "%s: %s\n" "REQUEST_TYPE" "$REQUEST_TYPE" 1>&2
      printf "%s\n" "$RESPONSE" 1>&2
      exit "$RC"
    fi

    printf '{"data":"%s"}' "$(printf "$RESULT" | base64 -w 0)"
    EOT
  ]
}

variable "name" {}
variable "name_id" {}
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
  description = "Default cloud provider to use for the cluster"
  type = string
  default = "aws"
  nullable = false
  validation {
    condition = contains([
      "aws",
      "azure",
      "gcp",
    ], var.cloud_provider)
    error_message = "Invalid cloud provider: ${var.cloud_provider}. Valid options are: aws, azure, gcp"
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

      # superuser not allowed for biganimal-hosted clusters
      superuser_access = values.cloud_account ? true : false

      # Format the cloud provider id
      cloud_provider_id = values.cloud_account ? var.cloud_provider : "bah:${var.cloud_provider}"
    }))
  }

  cloud_account_non_pgd = (
    alltrue([for group in var.data_groups: group.cloud_account == true])
    && !local.use_pgd
    ? true : false
  )

}

resource "toolbox_external" "witness_node_params" {
  for_each = local.use_wal_volume ? var.witness_groups : {}
  program = [
    "bash",
    "-c",
    <<EOT
    set -eou pipefail
    # When using pgd, we need to get the witness node parameters
    # Get json object from stdin
    IFS='' read -r input || [ -n "$input" ]

    # BigAnimal API accepts either an access key or a bearer token
    # The access token should be preferred if set and non-empty.
    AUTH_HEADER=""
    if [ ! -z "$${BA_ACCESS_KEY:+''}" ]
    then
      AUTH_HEADER="x-access-key: $BA_ACCESS_KEY"
    else
      AUTH_HEADER="authorization: Bearer $BA_BEARER_TOKEN"
    fi

    URI="$${BA_API_URI:=https://portal.biganimal.com/api/v3/}"
    ENDPOINT="projects/${var.project.id}/utils/calculate-witness-group-params"
    REQUEST_TYPE="PUT"
    DATA='{"provider":{"cloudProviderId":"${ each.value.cloud_account ? each.value.cloud_service_provider : "bah:${each.value.cloud_service_provider}" }"},"region":{"regionId":"${each.value.region}"}}'
    RESULT=$(curl --silent --show-error --fail-with-body --location --request $REQUEST_TYPE --header "content-type: application/json" --header "$AUTH_HEADER" --url "$URI$ENDPOINT" --data "$DATA")
    RC=$?

    if [[ $RC -ne 0 ]];
    then
      printf "%s\n" "$RESULT" 1>&2
      exit $RC
    fi

    printf "$RESULT"
    EOT
  ]
}

locals {
  witness_groups = {
    for name, values in var.witness_groups : name => (merge(values, {
      # Format the cloud provider id
      cloud_provider_id = values.cloud_account ? values.cloud_service_provider : "bah:${values.cloud_service_provider}"
      instance_type = can(toolbox_external.witness_node_params[name]) ? jsondecode(toolbox_external.witness_node_params[name].result.data).instanceType.instanceTypeId : ""
      storage = {
        type = can(toolbox_external.witness_node_params[name]) ? jsondecode(toolbox_external.witness_node_params[name].result.data).storage.volumeTypeId : ""
        properties = can(toolbox_external.witness_node_params[name]) ? jsondecode(toolbox_external.witness_node_params[name].result.data).storage.volumePropertiesId : ""
        size = can(toolbox_external.witness_node_params[name]) ? jsondecode(toolbox_external.witness_node_params[name].result.data).storage.size : ""
        iops = can(toolbox_external.witness_node_params[name]) ? jsondecode(toolbox_external.witness_node_params[name].result.data).storage.iops : ""
        # Currently unused
        #throughput = toolbox_external.witness_node_params[name].result.data.storage.throughput
      }
    }))
  }

  cluster_name = format("%s-%s", var.name, var.name_id)

  // Create an object that excludes any null objects
  TERRAFORM_API_MAPPING = {
    storage = {
      iops = "iops"
      throughput = "throughput"
      size_gb = "size"
      properties = "volumePropertiesId"
      type = "volumeTypeId"
    }
  }

  // Remove null values from the volume properties and save with the api variable naming as the key
  // Size must be saved as a string and with the Gi suffix
  API_DATA_CLUSTER = [
    for group_name, group_values in local.data_groups: {
      clusterName = local.cluster_name
      # causes error now that we have pgd
      # │ {"error":{"status":400,"message":"Bad Request","errors":[{"message":"Cluster type \"cluster\" cannot be changed to
      # │ \"single\"","path":".body.clusterType"}],"reference":"upmrid/TpKTaO-o4PFGK_4ZZPtCg/UrN6Js0I9On9V5MKI4XiX","source":"API"}}
      # │ State: exit status 22
      # clusterType = group_values.type
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
        for key, value in group_values.volume : local.TERRAFORM_API_MAPPING.storage[key] =>
          key == "size_gb" ? "${value} Gi" : tostring(value) if value != null
      }
      walStorage = {
        for key, value in group_values.wal_volume == null ? {} : group_values.wal_volume : local.TERRAFORM_API_MAPPING.storage[key] =>
          key == "size_gb" ? "${value} Gi" : tostring(value) if value != null
      }
      # required
      provider = { cloudProviderId = group_values.cloud_provider_id }
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
      superuserAccess = group_values.superuser_access
      maintenanceWindow = {
        isEnabled = group_values.maintenance_window.is_enabled
        startDay = group_values.maintenance_window.start_day
        startTime = group_values.maintenance_window.start_time
      }
    }
  ][0]

  API_DATA_PGD = {
    clusterName = local.cluster_name
    clusterType = "cluster"
    password = local.password
    groups = [
      for obj in flatten([[ for group_name, group_values in local.data_groups: {
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
          for key, value in group_values.volume : local.TERRAFORM_API_MAPPING.storage[key] =>
            key == "size_gb" ? "${value} Gi" : tostring(value) if value != null
        }
        walStorage = {
          for key, value in group_values.wal_volume == null ? {} : group_values.wal_volume : local.TERRAFORM_API_MAPPING.storage[key] =>
            key == "size_gb" ? "${value} Gi" : tostring(value) if value != null
        }
        # required 
        provider = { cloudProviderId = group_values.cloud_provider_id }
        clusterArchitecture = {
            clusterArchitectureId = "pgd"
            nodes = group_values.node_count
        }
        region = { regionId = group_values.region }
        pgVersion = { pgVersionId = tostring(group_values.engine_version) }
        pgType = { pgTypeId = group_values.engine }
        pgConfig = group_values.settings
        privateNetworking = !var.publicly_accessible
        backupRetentionPeriod = "1d"
        cspAuth = false
        readOnlyConnections = false
        # unavailable for pgd
        # superuserAccess = group_values.superuser_access
        maintenanceWindow = {
          isEnabled = group_values.maintenance_window.is_enabled
          startDay = group_values.maintenance_window.start_day
          startTime = group_values.maintenance_window.start_time
        }
      }], [ for group_name, group_values in local.witness_groups: {
        clusterType = "witness_group"
        clusterArchitecture = {
          clusterArchitectureId = "pgd"
          nodes = 1
        }
        instanceType = { instanceTypeId = group_values.instance_type }
        provider = { cloudProviderId = group_values.cloud_provider_id }
        region = { regionId = group_values.region }
        # Storage values prefetched from the api for witness groups
        storage = {
          volumePropertiesId = group_values.storage.properties
          volumeTypeId = group_values.storage.type
          size = group_values.storage.size
        }
        maintenanceWindow = {
          isEnabled = group_values.maintenance_window.is_enabled
          startDay = group_values.maintenance_window.start_day
          startTime = group_values.maintenance_window.start_time
        }
      }],
    # Remove null/empty groups
    ]): obj if obj != null && obj != {}]
  }

  # Ternary requires consistent types.
  # A workaround is to setup a list of objects and then use a conditional to choose the correct index.
  API_DATA = [local.API_DATA_CLUSTER, local.API_DATA_PGD][local.use_pgd ? 1 : 0]
}
