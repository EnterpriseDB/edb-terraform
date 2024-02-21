variable "vpc_id" {}
variable "tags" {}
variable "ports" {}
variable "cluster_name" {}
variable "public_cidrblocks" {
  type = list(string)
  default = ["0.0.0.0/0"]
  nullable = false
}
variable "internal_cidrblocks" {
  type = list(string)
  default = []
  nullable = false
}
variable "service_cidrblocks" {
  type = list(string)
  default = []
  nullable = false
}

locals {
  # AWS will fail if there are duplicate ingress/egress defined for any protocol-port combination.
  # Collapse duplicate rules so only one rule will be created
  # Use protocol, port and type to create a key
  # Use group_by to gather cidrs and description as a list
  # Create mapping with new key and collapse protocol, port, description and cidrs
  mod_ports = [
    for port in var.ports : merge(port, {
        cidrs = concat(port.cidrs,
          try(port.defaults, "") == "service" ? var.service_cidrblocks :
          try(port.defaults, "") == "public" ? var.public_cidrblocks :
          try(port.defaults, "") == "internal" ? var.internal_cidrblocks :
          []
    )})
  ]
  # Remove any 'service' rules that define an empty list of cidrblocks since it is meant for temporary use and might be empty
  ports = [for port in local.mod_ports: port if length(port.cidrs) > 0 || try(port.defaults, "") != "service"]

  port_rules_cidr_blocks = {
    for port in local.ports:
      join("_", formatlist("%#v", [port.protocol, port.port, port.to_port, port.type])) 
      => port.cidrs...
    }

  port_rules_descriptions = {
    for port in local.ports:
      join("_", formatlist("%#v", [port.protocol, port.port, port.to_port, port.type])) 
      => coalesce(port.description, "default")...
    }
  port_rules_mapping = {
    for port in local.ports:
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
  # Expand the list back out with 1 rule per cidrblock since AWS fails to track the rules properly
  # Ref: https://github.com/hashicorp/terraform-provider-aws/issues/29797
  rules = merge([
    for name, rule in local.merged_rules: {
      for cidr in rule.cidrs: 
        format("%s_%s", name, cidr) => merge(rule, {
          cidrs = [cidr]
        })
    }
  ]...)
}
