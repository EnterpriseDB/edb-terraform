resource "aws_security_group" "rules" {
  for_each = {
    # preserve ordering
    for index, values in var.ports:
      format("0%.3d",index) => values
  }
  name = format("%s_%s_%s_%s", var.project_tag, var.cluster_name, each.value.protocol, each.key)
  description = each.value.description
  vpc_id = var.vpc_id
  ingress {
      from_port   = each.value.protocol == "icmp" ? 8 : each.value.port != null ? each.value.port : -1
      to_port     = each.value.port != null && each.value.protocol != "icmp"  ? each.value.port : -1
      protocol    = each.value.protocol
      cidr_blocks = each.value.ingress_cidrs != null ? each.value.ingress_cidrs : var.ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = each.value.egress_cidrs != null ? each.value.egress_cidrs : var.egress_cidrs
  }

  tags = {
    Name = format("%s_%s_%s_%s", var.project_tag, var.cluster_name, each.value.protocol, each.key)
  }
}

# Default is removed from VPC when this resource is used
# Manually add it back to allow instances to have outbound access
# Should be moved to network tags so machines can specify if they need public access
resource "aws_security_group" "OUTBOUND_ACCESS" {
  vpc_id = var.vpc_id
  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
