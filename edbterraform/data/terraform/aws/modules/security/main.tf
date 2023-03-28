resource "aws_security_group" "rules" {
  name = format("%s_%s", var.project_tag, var.cluster_name)
  vpc_id = var.vpc_id

  tags = {
    Name = format("%s_%s", var.project_tag, var.cluster_name)
  }
}

resource "aws_security_group_rule" "rule" {
  for_each = local.merged_rules
  security_group_id = aws_security_group.rules.id
  description = each.value.description
  type = each.value.type

  from_port   = each.value.protocol == "icmp" ? 8 : each.value.port != null ? each.value.port : -1
  to_port     = each.value.port != null && each.value.protocol != "icmp"  ? each.value.port : -1
  protocol    = each.value.protocol
  cidr_blocks = each.value.cidrs

  lifecycle {
    precondition {
      condition     = each.value.type == "ingress" || each.value.type == "egress"
      error_message = "${each.key} has type ${each.type}. Must be ingress or egress."
    }
  }
}
