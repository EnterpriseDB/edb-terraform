resource "aws_security_group" "rules" {
  name = format("%s", var.cluster_name)
  vpc_id = var.vpc_id

  tags = merge({
    Name = format("%s", var.cluster_name)
  }, var.tags)
}

resource "aws_security_group_rule" "rule" {
  for_each = local.merged_rules
  security_group_id = aws_security_group.rules.id
  description = each.value.description
  type = each.value.type

  from_port   = each.value.protocol == "icmp" ? 8 : each.value.port != null ? each.value.port : -1
  to_port     = (
      each.value.to_port != null && each.value.protocol != "icmp"  ? each.value.to_port : 
      each.value.port != null && each.value.protocol != "icmp" ? each.value.port : -1
    )
  protocol    = each.value.protocol
  cidr_blocks = each.value.cidrs

  lifecycle {
    precondition {
      condition     = each.value.type == "ingress" || each.value.type == "egress"
      error_message = "${each.key} has type ${each.value.type}. Must be ingress or egress."
    }

    precondition {
      error_message = "port defaults must be one of: service, public, internal or an empty string ('')"
      condition = contains(["service", "internal", "public", ""], try(each.value.defaults, ""))
    }

    precondition {
      condition     = each.value.cidrs != null && length(each.value.cidrs) > 0
      error_message = <<-EOT
        Cidr blocks cannot be an empty list.
        - AWS Security groups are an allow list meaning an empty list is the same as not having the rule itself.
        - When defaults is set to 'service' and has no cidrs defined, it is removed from the list to avoid creation.
        The AWS API will return the following error after 5-10 minutes:
          Error: waiting for Security Group (sg-xxxx) Rule (sgrule-xxxx) create: couldn't find resource
        Rule: ${jsonencode(each.value)}
      EOT
    }
  }
}
