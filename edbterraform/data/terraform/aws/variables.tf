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

