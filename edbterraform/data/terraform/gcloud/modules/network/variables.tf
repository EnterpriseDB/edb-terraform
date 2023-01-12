variable "network_name" {}
variable "ip_cidr_range" {
    type = string
    default = "10.0.0.0/16"

    validation {
        condition = can(cidrhost(var.ip_cidr_range, 0))
        error_message = "unusable IPv4 CIDR"
    }
}
variable "name" {}