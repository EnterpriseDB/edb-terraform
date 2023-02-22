variable "machine" {}
variable "vpc_id" {}
variable "cidr_block" {}
variable "az" {}
variable "ssh_user" {}
variable "ssh_pub_key" {}
variable "ssh_priv_key" {}
variable "use_agent" {
  default = false
}
variable "custom_security_group_ids" {}
variable "key_name" {}
variable "operating_system" {}
variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  # Create a list of possible device names
  prefix = "/dev/"
  base = ["sd", "xvd", "hd"]
  letters = [
    "f", "g", "h", "i", 
    "j", "k", "l", "m", 
    "n", "o", "p", "q"
  ]
  # List(List(String))
  # [[ "/dev/sdf" , "/dev/xvdf", "/dev/hdf" ], ]
  linux_device_names = [
    for letter in local.letters:
      formatlist("${local.prefix}%s${letter}", local.base)
  ]
  # List(String) with comma delimiter
  # [ "/dev/sdf,/dev/xvdf,/dev/hdf" , ]
  string_device_names = [
    for names in local.linux_device_names:
      format("%s,%s,%s", names...)
  ]
}
