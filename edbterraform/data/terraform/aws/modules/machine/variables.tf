variable "machine" {}
variable "public_cidrblocks" {}
variable "service_cidrblocks" {}
variable "internal_cidrblocks" {}
variable "outbound_security_groups" {}
locals {
  # Allow machine default outbound access if no egress is defined
  egress_defined = anytrue([for port in var.machine.spec.ports: port.type=="egress"])
  security_group_ids = concat(var.custom_security_group_ids, local.egress_defined ? [] : var.outbound_security_groups)
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
variable "image_info" {}

locals {
  # Skip execution of prearranged volume script if the object is null/empty or all key-values contain empty/null values.
  execute_preattached_volumes = !alltrue([for k,v in try(var.machine.spec.preattached_volumes, {}): v == null || v == {} || v == ""])

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
