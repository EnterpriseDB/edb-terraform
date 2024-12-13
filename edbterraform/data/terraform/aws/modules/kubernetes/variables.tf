variable "region" {
  default = "us-east-1"
}

variable "name" {
  default = "K8s-Default-Name"
  nullable = false
}

variable "name_id" {
  type     = string
  default  = null
  nullable = true
}

locals {
  name = var.name_id != null && var.name_id != "" ? "${var.name}-${var.name_id}" : var.name
  vpc_name = format("eks-%s", local.name)
}

variable "runtime_service_cidrblocks" {
  description = "CIDRs to allow access to the kubernetes api from a public network. Private networking (reused vpc, peered vpc, private endpoints) access enabled by default"
  type = list(string)
  default = []
  nullable = false
}

variable "config_service_cidrblocks" {
  description = "CIDRs to allow access to the kubernetes api from a public network. Private networking (reused vpc, peered vpc, private endpoints) access enabled by default"
  type = list(string)
  default = []
  nullable = false
}

variable "disable_public_access" {
  description = "Disable public access to the kubernetes api. Required to force refresh of the public access cidrs for eks"
  type = bool
  default = false
  nullable = false
}

locals {
  # If the service_cidrblocks list is an empty list then disable public access to the kubernetes api.
  # This ensures that the kubernetes api is not accidentally exposed to all of the internet and forces the use of a bastion host.
  # This also works as a workaround for the bug in the aws_eks_cluster resource which does not allow for the public_access_cidrs to be updated.
  # Error:
  # | module.kubernetes_us_west_2["mydb2"].module.eks.aws_eks_cluster.this[0]: Modifying... [id=mydb2-2f7a3a82]
  # | Error: updating EKS Cluster (mydb2-2f7a3a82) VPC configuration: operation error EKS: UpdateClusterConfig, https response error StatusCode: 400, RequestID: 9ec38b4f-3a0f-4b44-9e4c-a58c84dea2a8, InvalidParameterException: Cluster is already at the desired configuration with endpointPrivateAccess: true , endpointPublicAccess: true, and Public Endpoint Restrictions: [0.0.0.0/0]
  # Workaround:
  # - disable public access by setting an empty access list or set disable_public_access to 'true' and 'terraform apply'
  # - re-enable public access by adding the new access list and set disable_public_access to 'false' and 'terraform apply'
  service_cidrblocks = setunion(var.runtime_service_cidrblocks, var.config_service_cidrblocks)
  public_access = var.disable_public_access || (local.service_cidrblocks) == 0 ? false : true
  public_access_cidrs = local.public_access ? local.service_cidrblocks : null
}

variable "cluster_version" {
  type = string
  default = "1.28"
  nullable = false
}

variable "desiredCapacity" {
  default = 3
}

variable "maxCapacity" {
  default = 3
}

variable "minCapacity" {
  default = 1
}

variable "instanceType" {
  default = "c6a.xlarge"
}

variable "vpcCidr" {
  default = "172.16.0.0/16"
}

variable "privateSubnet1" {
  default = "172.16.1.0/24"
}

variable "privateSubnet2" {
  default = "172.16.2.0/24"
}

variable "privateSubnet3" {
  default = "172.16.3.0/24"
}

variable "publicSubnet1" {
  default = "172.16.4.0/24"
}

variable "publicSubnet2" {
  default = "172.16.5.0/24"
}

variable "publicSubnet3" {
  default = "172.16.6.0/24"
}

variable "tags" {
  default = {}
}
