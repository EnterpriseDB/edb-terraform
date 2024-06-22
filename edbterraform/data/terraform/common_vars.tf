variable "create_servers_yml" {
  description = "Create a file with the server names, IPs, and other outputs instead of using `terraform output -json servers`"
  default = true
  nullable = false
}

variable "spec" {
  description = "Variable is meant to represent the yaml input file handled through python and is meant to be passed through to module/specification var.spec"
  nullable    = false
}

variable "cloud_service_provider" {
  description = "Target cloud service provider"
  type = string
  nullable = false
  validation {
    condition = contains(["aws", "gcp", "azure"], var.cloud_service_provider)
    error_message = "cloud_service_provider must be one of 'aws', 'gcp', or 'azure'"
  }
}

variable "ba_project_id" {
  description = "BigAnimal project ID to use if not defined within the biganimal configuration"
  type = string
  nullable = true
  default = null
}

variable "ba_pg_image" {
  description = "Dev only: BigAnimal postgres image to use if not defined within the biganimal configuration"
  type = string
  nullable = true
  default = null
}

variable "ba_proxy_image" {
  description = "Dev only: BigAnimal proxy image to use if not defined within the biganimal configuration"
  type = string
  nullable = true
  default = null
}

variable "ba_ignore_image" {
  description = "Ignore biganimal custom images"
  type = bool
  nullable = false
  default = false
}

variable "public_cidrblocks" {
  description = "Public CIDR block"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "service_cidrblocks" {
  description = "Default cidr blocks for service ports"
  type = list(string)
  default = []
}

variable "force_dynamic_ip" {
  description = "Force the use of a dynamic IP address which will be appended to service_cidrblocks"
  type = bool
  default = false
}

variable "force_service_machines" {
  description = "Force the use of service_cidrblocks and set up an ssh rule for the machines"
  type = bool
  default = false
}

variable "force_service_biganimal" {
  description = "Force the use of service_cidrblocks in biganimals allowed_ip_ranges"
  type = bool
  default = false
}

variable "dynamic_service_ip_mask" {
  type = number
  default = 32
  nullable = false
}

variable "dynamic_service_ip_url" {
  type = string
  description = "Endpoint to get the dynamic IP address."
  default = "https://checkip.amazonaws.com/"
  nullable = false
}

# Keep at the root level so that it is always a known value.
# Data sources within modules are not computed until the module is instantiated,
#  which causes for_each loops to fail since it is an unknown computed value.
data "http" "instance_ip" {
  count = var.force_dynamic_ip ? 1 : 0
  url = var.dynamic_service_ip_url
  request_headers = {
    Accept = "application/text"
  }
}

locals {
  # format the ip with the mask to get a valid cidr block
  # ex: cidrhost("1.2.3.4/32",0) => 1.2.3.4 | cidrhost("1.2.3.4/24",0) => 1.2.3.0 | cidrhost("1.2.3.4/16",0) => 1.2.0.0 | cidrhost("1.2.3.4/8",0) => 1.0.0.0
  dynamic_ip = var.force_dynamic_ip ? [
    "${cidrhost(
        format("%s/%s",
          split("/", chomp(data.http.instance_ip[0].response_body))[0], # Drop any prefined masks
          var.dynamic_service_ip_mask),
        0)
    }/${var.dynamic_service_ip_mask}"
  ] : []
  service_cidrblocks = concat(var.service_cidrblocks, local.dynamic_ip)
  biganimal_service_cidrblocks = var.force_service_biganimal ? local.service_cidrblocks : []
}
