/*
Spec object is meant to represent inputs needed to get a valid configuration
for use with the rest of the cloud provider module collection.
In most cases:
* optional() should be used so that null is passed further down for the module to handle
  * Module require null to be handled:
    * set a default if desired: optional(type,default) 
  * Need to set a default after the initial object is set:
    * dynamically set variables with the use of locals and null_resource
    * set an output variable for use with other modules
* sibling modules should handle most errors with variable validations and preconditions
  so they are caught during terraform plan
* provider implementations vary and errors might need to be caught eariler, as last resort, 
  use variable validations and data source preconditions/postcondition here for use with terraform plan
*/
# external data source used as a workaround to validate all variables under a single object with preconditions
locals {
  # temp hold all variables to be validated as a single object
  temp_spec = {
    tags       = var.tags
    ssh_key    = var.ssh_key
    images     = var.images
    regions    = var.regions
    machines   = var.machines
    databases  = var.databases
    aurora     = var.aurora
    biganimal  = var.biganimal
    kubernetes = var.kubernetes
  }
}
data "external" "spec_validate" {
  query = {
    spec = base64encode(jsonencode(local.temp_spec))
  }
  program = [
    "bash",
    "-c",
    <<EOT
    SPEC="$(jq -r .spec)"
    printf '{"spec":"%s"}' "$SPEC"
    EOT
  ]
}
locals {
  spec = jsondecode(base64decode(data.external.spec_validate.result.spec))
}

variable "force_ssh_access" {
  description = "Force append a service rule for ssh access"
  default = false
  type = bool
  nullable = false
}

variable "ba_project_id_default" {
  description = "BigAnimal project ID"
  type = string
  nullable = true
}

variable "ba_pg_image_default" {
  description = "Dev only: BigAnimal postgres image to use if not defined within the biganimal configuration"
  type = string
  nullable = true
  default = null
}

variable "ba_proxy_image_default" {
  description = "Dev only: BigAnimal proxy image to use if not defined within the biganimal configuration"
  type = string
  nullable = true
  default = null
}

variable "ba_ignore_image_default" {
  description = "Ignore biganimal custom images"
  type = bool
  nullable = false
  default = false
}

locals {
  cluster_name = can(local.spec.tags.cluster_name) ? local.spec.tags.cluster_name : "AWS-Cluster-default"
  created_by = can(local.spec.tags.created_by) ? local.spec.tags.created_by : "EDB-Terraform-AWS"
}
