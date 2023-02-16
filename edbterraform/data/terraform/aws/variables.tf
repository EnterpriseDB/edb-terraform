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

# IAM User Name
variable "user_name" {
  description = "Desired name for AWS IAM User"
  type        = string
  default     = "bdrbench-edb-iam-postgres"
}

# IAM Force Destroy
variable "user_force_destroy" {
  description = "Force destroying AWS IAM User and dependencies"
  type        = bool
  default     = true
}

variable "project_tag" {
  type    = string
  default = "edb_terraform"
}

variable "vpc_tag" {
  default = "edb_terraform_vpc"
}

# Subnets
variable "public_subnet_tag" {
  default = "edb_terraform_public_subnet"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
  default     = ""
}

variable "custom_security_group_id" {
  description = "Security Group assign to the instances. Example: 'sg-12345'."
  type        = string
  default     = ""
}
