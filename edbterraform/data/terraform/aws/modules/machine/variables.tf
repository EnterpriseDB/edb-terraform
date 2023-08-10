variable "machine" {}
locals {
  # Allow machine default outbound access if no egress is defined
  egress_defined = anytrue([for port in var.machine.spec.ports: port.type=="egress"])
  machine_ports = concat(var.machine.spec.ports, 
      (local.egress_defined ? [] : [{"type"="egress", "cidrs"=["0.0.0.0/0"], "protocol"="-1", "port": null, "to_port": null, "description": "Default Egress if not defined"}])
    )
}

variable "vpc_id" {}
variable "subnet_id" {}
variable "cidr_block" {}
variable "az" {}
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
  additional_volumes_length = length(lookup(var.machine.spec, "additional_volumes", []))
  additional_volumes_count = local.additional_volumes_length > 0 ? 1 : 0
  additional_volumes_map = { for i, v in lookup(var.machine.spec, "additional_volumes", []) : i => v }
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
  # Default filesystem related variables
  filesystem = "xfs"
  mount_options = ["noatime", "nodiratime", "logbsize=256k", "allocsize=1m"]
}
