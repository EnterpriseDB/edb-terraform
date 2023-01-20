variable "machine" {}
variable "zone" {}
variable "ssh_user" {}
variable "ssh_pub_key" {}
variable "ssh_priv_key" {}
variable "ssh_metadata" {}
variable "cluster_name" {}
variable "operating_system" {}
variable "subnet_name" {}
variable "name_id" { default = "0" }
variable "ip_forward" {
  type     = bool
  default  = false
  nullable = false
}
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
