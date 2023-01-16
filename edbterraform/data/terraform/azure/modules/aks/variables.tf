variable "aksServicePrincipalAppId" {
  default = "<YourServicePrincipalAppId"
}

variable "aksServicePrincipalClientSecret" {
  default = "<YourServicePrincipalClientSecret>"
}

variable "nodeCount" {
  default = 3
}

variable "dnsPrefix" {
  default = "EDB-k8s"
}

# Refer to https://azure.microsoft.com/global-infrastructure/services/?products=monitor for available Log Analytics regions.
variable "logAnalyticsWorkspaceLocation" {
  default = "westus"
}

variable "logAnalyticsWorkspaceName" {
  default = "EDBk8sLogAnalyticsWorkspaceName"
}

# Refer to https://azure.microsoft.com/pricing/details/monitor/ for Log Analytics pricing
variable "logAnalyticsWorkspaceSku" {
  default = "PerGB2018"
}

variable "resourceGroupLocation" {
  default     = "westus"
  description = "Location of the resource group."
}

variable "resourceGroupNamePrefix" {
  default     = "EDB-k8s-rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "vmSize" {
  default     = "Standard_D2_v2"
  description = "Azure VM Size"
}

variable "environment" {
  default     = "Sandbox"
  description = "Target Environment Tag"
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