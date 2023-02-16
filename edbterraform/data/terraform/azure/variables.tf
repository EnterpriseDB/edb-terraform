variable "spec" {
  description = "Variable is meant to represent the yaml input file handled through python and is meant to be passed through to module/specification var.spec"
  nullable    = false
}

variable "source_ranges" {
  default = "0.0.0.0/0"
}

variable "public_cidrblock" {
  default = "0.0.0.0/0"
}

# Tags
variable "project_name" {
  default = "edb"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "azure-dev"
}

variable "resource_tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}

variable "subnetwork_name" {
  # Must have network_name tag as a prefix
  default = "edb-network-subnetwork"
}

variable "project_tag" {
  type    = string
  default = "edb-gcloud-deployment"
}

# Subnets
variable "subnet_name" {
  default = "edb-public-subnet"
}

variable "subnet_tag" {
  default = "edb-public-subnet"
}

variable "vpc_tag" {
  default = "edb-vpc"
}
