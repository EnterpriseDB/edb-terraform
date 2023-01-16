variable "regions" {}
variable "machines" {}
variable "cluster_name" {}
variable "ssh_pub_key" {}
variable "ssh_priv_key" {}
variable "ssh_user" {}
variable "operating_system" {}
variable "aks" {}

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

variable "created_by" {
  type        = string
  description = "EDB terraform Azure"
  default     = "EDB terraform Azure"
}








