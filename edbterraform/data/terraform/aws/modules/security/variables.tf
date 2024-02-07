variable "vpc_id" {}
variable "tags" {}
variable "ports" {}
variable "cluster_name" {}
variable "ingress_cidrs" {
  type = list(string)
  default = [ "0.0.0.0/0" ]
}
variable "egress_cidrs" {
  type = list(string)
  default = [ "0.0.0.0/0" ]
}

locals {
  # AWS will fail if there are duplicate ingress/egress defined for any protocol-port combination.
  # Collapse duplicate rules so only one rule will be created
  # Use protocol, port and type to create a key
  # Use group_by to gather cidrs and description as a list
  # Create mapping with new key and collapse protocol, port, description and ingress_cidrs
  port_rules_cidr_blocks = {
    for port in var.ports:
      join("_", formatlist("%#v", [port.protocol, port.port, port.to_port, port.type])) 
      => coalesce(port.cidrs, var.ingress_cidrs)...
    }

  port_rules_descriptions = {
    for port in var.ports:
      join("_", formatlist("%#v", [port.protocol, port.port, port.to_port, port.type])) 
      => coalesce(port.description, "default")...
    }
  port_rules_mapping = {
    for port in var.ports:
      join("_", formatlist("%#v", [port.protocol, port.port, port.to_port, port.type])) 
       => port...
  }
  merged_rules = {
    for name, ports in local.port_rules_mapping:
      replace(name, "\"", "") => merge(ports[0], {
        "cidrs": distinct(flatten(local.port_rules_cidr_blocks[name])),
        "description": join(" _ ", distinct(local.port_rules_descriptions[name]))
      })
  }
}
