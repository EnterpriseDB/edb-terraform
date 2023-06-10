variable "machine" {}
variable "zone" {}
variable "ssh_priv_key" {}
variable "ssh_pub_key" {}
variable "cluster_name" {}
variable "operating_system" {
  type = object({
    name = optional(string)
    family = optional(string)
    project = optional(string)
    ssh_user = string
  })

  validation {
    condition = (
      (var.operating_system.name == null ? 0 : 1) + 
      (var.operating_system.family == null ? 0 : 1) == 1
    )
    error_message = "only one, name or family must be defined"
  }
}
variable "subnet_name" {}
variable "name_id" { default = "0" }
variable "use_agent" {
  default = false
}
variable "ip_forward" {
  type     = bool
  default  = false
  nullable = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
locals {
  # gcloud label restrictions:
  # - lowercase letters, numeric characters, underscores and dashes
  # - 63 characters max
  # to match other providers as close as possible,
  # we will do any needed handling and continue to treat
  # key-values as tags even though they are labels under gcloud
  labels = { for key,value in var.tags: key => lower(replace(value, ":", "_"))}
}

locals {
  prefix = "/dev/disk/by-id/google-"
  base = ["sd"]
  letters = [
    "f", "g", "h", "i", 
    "j", "k", "l", "m", 
    "n", "o", "p", "q"
  ]
  # List(List(String))
  # [[ "/dev/disk/by-id/google-sdf" ], ]
  linux_device_names = [
    for letter in local.letters:
      formatlist("${local.prefix}%s${letter}", local.base)
  ]
  # List(String) with comma delimiter
  # [ "/dev/disk/by-id/google-sdf" , ]
  string_device_names = [
    for names in local.linux_device_names:
      format("%s", names...)
  ]
}
