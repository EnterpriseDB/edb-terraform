variable "aksServicePrincipalAppId" {
  default = "<YourServicePrincipalAppId"
}

variable "aksServicePrincipalClientSecret" {
  default = "<YourServicePrincipalClientSecret>"
}

variable "cluster_name" {
  default = "EDB-k8s"
}

variable "ssh_user" {
  type     = string
  nullable = false
}

variable "nodeCount" {
  default = 3
}

# Refer to https://azure.microsoft.com/global-infrastructure/services/?products=monitor for available Log Analytics regions.
variable "logAnalyticsWorkspaceLocation" {
  type = string
}

variable "logAnalyticsWorkspaceName" {
  default = "LogAnalyticsWorkspaceName"
}

# Refer to https://azure.microsoft.com/pricing/details/monitor/ for Log Analytics pricing
variable "logAnalyticsWorkspaceSku" {
  default = "PerGB2018"
}

variable "resourceGroupLocation" {
  default     = "westus"
  description = "Location of the resource group."
}

variable "resourceGroupName" {
  default     = "RG"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "vmSize" {
  default     = "Standard_D2_v2"
  description = "Azure VM Size"
}

variable "tags" {
  type = map(any)
}

variable "solutionName" {
  default     = "EDB K8s Cluster and Dashboard"
  description = "Descriptive Name for the Application"
}

variable "publisherName" {
  default     = "EDB"
  description = "Publisher Name"
}

variable "sshPublicKey" {
  default = "~/.ssh/id_rsa.pub"
}

variable "region" {
  default = "westus"
}