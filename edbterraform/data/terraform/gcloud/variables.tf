variable "regions" {}
variable "machines" {}
variable "databases" {}
variable "cluster_name" {}
variable "ssh_pub_key" {}
variable "ssh_priv_key" {}
variable "ssh_user" {}
variable "operating_system" {}

variable "ip_cidr_range" {
  default = "10.0.0.0/16"
}

variable "source_ranges" {
  default = "0.0.0.0/0"
}

variable "public_cidrblock" {
  default = "0.0.0.0/0"
}

# Ansible Add Hosts Filename
variable "add_hosts_filename" {
  type    = string
  default = "add_host.sh"
}

# Tags
variable "project_name" {
  default = "edb"
}

variable "environment" {
  description = "Environment name"
  type = string
  default = "gcloud-dev"
}

variable "resource_tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default = { }
}

variable "network_name" {
  default = "edb-network"
}

variable "subnetwork_name" {
  # Must have network_name tag as a prefix
  default = "edb-network-subnetwork"
}

variable "project_tag" {
  type    = string
  default = "edb-gcloud-deployment"
}

# Storage
variable "storageaccount_name" {
  description = "Name of the bucket for storing related data of deployment"
  type        = string
  default     = "edbpostgres"
}

variable "storagecontainer_name" {
  description = "Name of the bucket for storing related data of deployment"
  type        = string
  default     = "edbstoragecontainer"
}

# VNet
variable "vnet_name" {
  type    = string
  default = "edb_vnet"
}

# Resource Group
variable "resourcegroup_tag" {
  default = "edb-resource-group"
}

variable "resourcegroup_name" {
  default = "edb-resource-group"
}

# Subnets
variable "subnet_name" {
  default = "edb-public-subnet"
}

variable "subnet_tag" {
  default = "edb-public-subnet"
}

variable "public_subnet_tag" {
  default = "edb-public-subnet"
}

variable "vpc_tag" {
  default = "edb-vpc"
}

# Security Group
variable "securitygroup_name" {
  default = "edb_security_group"
}

variable "created_by" {
  type        = string
  description = "EDB terraform GCP"
  default     = "EDB terraform GCP"
}