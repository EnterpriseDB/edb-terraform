variable "machine" {}
variable "region" {}
variable "cluster_name" {}
variable "subnetwork" {}
variable "network" {}
variable "node_count" {
  type = number
}
variable "name_id" { default = "0" }
variable "tags" {
  type    = map(string)
  default = {}

  validation {
    condition = alltrue([
      for key, value in var.tags :
      lower(key) == key && lower(value) == value
    ])
    error_message = <<-EOT
GCloud expects all tags(labels) to be lowercase
Fix the following tags:
%{for key, value in var.tags}
%{if !(lower(key) == key && lower(value) == value)}
  ${key}: ${value}
%{endif}
%{endfor}
    EOT
  }

}
