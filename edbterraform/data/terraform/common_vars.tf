variable "create_servers_yml" {
  description = "Create a file with the server names, IPs, and other outputs instead of using `terraform output -json servers`"
  default = true
  nullable = false
}

variable "spec" {
  description = "Variable is meant to represent the yaml input file handled through python and is meant to be passed through to module/specification var.spec"
  nullable    = false
}

# VPC
variable "public_cidrblock" {
  description = "Public CIDR block"
  type        = string
  default     = "0.0.0.0/0"
}

variable "service_cidrblocks" {
  description = "Default cidr blocks for service ports"
  type = list(string)
  default = ["0.0.0.0/0"]
}
