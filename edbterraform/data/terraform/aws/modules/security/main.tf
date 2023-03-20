resource "aws_security_group" "rules" {
  name = format("%s_%s", var.project_tag, var.cluster_name)
  vpc_id = var.vpc_id

  tags = {
    Name = format("%s_%s", var.project_tag, var.cluster_name)
  }
}

resource "aws_security_group_rule" "ingress" {
  for_each = {
    # preserve ordering
    for index, values in var.ports:
      format("0%.3d",index) => values
  }
  security_group_id = aws_security_group.rules.id
  description = each.value.description
  type = "ingress"

  from_port   = each.value.protocol == "icmp" ? 8 : each.value.port != null ? each.value.port : -1
  to_port     = each.value.port != null && each.value.protocol != "icmp"  ? each.value.port : -1
  protocol    = each.value.protocol
  cidr_blocks = each.value.ingress_cidrs != null ? each.value.ingress_cidrs : var.ingress_cidrs
}

# Default is removed from VPC when this resource is used
# Manually add it back to allow instances to have outbound access
# Should be moved to network tags so machines can specify if they need public access
resource "aws_security_group_rule" "OUTBOUND_ACCESS" {
  security_group_id = aws_security_group.rules.id
  description = "OUTBOUND access"
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = -1
  cidr_blocks = ["0.0.0.0/0"]
}
