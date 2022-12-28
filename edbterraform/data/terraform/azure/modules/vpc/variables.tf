variable "region" {}
variable "cidr_blocks" {
    type = list(string)
    default = []
    nullable = true
}
variable "name" {}
