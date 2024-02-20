variable "machine" {}
variable "public_cidrblocks" {}
variable "service_cidrblocks" {}
variable "internal_cidrblocks" {}
variable "force_ssh_access" {
  description = "Force append a service rule for ssh access"
  default = false
  type = bool
  nullable = false
}
locals {
  # Allow machine default outbound access if no egress is defined
  egress_defined = anytrue([for port in var.machine.spec.ports: port.type=="egress"])
  ssh_defined = anytrue([for port in var.machine.spec.ports: port.port == var.machine.spec.ssh_port])
  machine_ports = concat(var.machine.spec.ports, 
      (local.egress_defined ? [] : [{"type"="egress", "cidrs"=["0.0.0.0/0"], "protocol"="-1", "port": null, "to_port": null, "description": "Default Egress if not defined"}]),
      (!var.force_ssh_access || local.ssh_defined ? [] : [
        {"type": "ingress", "defaults": "service", "cidrs": [], "protocol": "tcp", "port": var.machine.spec.ssh_port, "to_port": var.machine.spec.ssh_port, "description": "Force SSH Access"},
        {"type": "egress", "defaults": "service", "cidrs": [], "protocol": "tcp", "port": var.machine.spec.ssh_port, "to_port": var.machine.spec.ssh_port, "description": "Force SSH Access"},
      ])
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
  base = ["xvd", "sd", "hd"]
  /*
  HVM device names:
  - root: /dev/sda1 or /dev/xvda
  - /dev/sd[a-z]
  - /dev/xvd[a-d][a-z]
    - /dev/xvddy and /dev/xvddz return an error
  - /dev/xvd[e-z]
  PVM (Legacy) device names:
  - root: /dev/sda1
  - /dev/sd[a-z]
  - /dev/sd[a-z][1-15]
  - /dev/hd[a-z]
  - /dev/hd[a-z][1-15]
  */
  letters = [
    "aa", "ab", "ac", "ad", "ae",
    "af", "ag", "ah", "ai", "aj",
    "ak", "al", "am", "an", "ao",
    "ap", "aq", "ar", "as", "at",
    "au", "av", "aw", "ax", "ay", "az",
    "ba", "bb", "bc", "bd", "be",
    "bf", "bg", "bh", "bi", "bj",
    "bk", "bl", "bm", "bn", "bo",
    "bp", "bq", "br", "bs", "bt",
    "bu", "bv", "bw", "bx", "by", "bz",
    "ca", "cb", "cc", "cd", "ce",
    "cf", "cg", "ch", "ci", "cj",
    "ck", "cl", "cm", "cn", "co",
    "cp", "cq", "cr", "cs", "ct",
    "cu", "cv", "cw", "cx", "cy", "cz",
    "da", "db", "dc", "dd", "de",
    "df", "dg", "dh", "di", "dj",
    "dk", "dl", "dm", "dn", "do",
    "dp", "dq", "dr", "ds", "dt",
    "du", "dv", "dw", "dx",
    "e", "f", "g", "h", "i",
    "j", "k", "l", "m", "n", 
    "o", "p", "q", "r", "s",
    "t", "u", "v", "w", "x", 
    "y", "z",
  ]
  # List(List(String))
  # [[ "/dev/sdf" , "/dev/xvdf", "/dev/hdf" ], ]
  linux_device_names = [
    for letter in local.letters:
      formatlist("${local.prefix}%s${letter}", local.base)
  ]
  # Default filesystem related variables
  filesystem = "xfs"
  mount_options = ["noatime", "nodiratime", "logbsize=256k", "allocsize=1m"]
}
