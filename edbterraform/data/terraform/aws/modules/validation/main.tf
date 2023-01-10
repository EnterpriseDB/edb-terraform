# Data sources run during plan
# UNLESS it relies on value which is known after apply 
# Validation locations by preference:
# 1. Inside of own module and executes during plan
# 2. Inside of specification module and executes during plan
# 3. Inside of validation module and executes during apply
variable "region" {}
variable "zones" {}

# availability data depends on providers region
data "aws_availability_zones" "list"{
  all_availability_zones = true
  filter {
    name = "state"
    values = [ "available" ]
  }
}

# Error: Missing pending object in plan
# https://github.com/hashicorp/terraform-provider-aws/pull/14853
# Originally within data.aws_availability zone
# but terraform bug when loading it multiple times
resource "null_resource" "zone_check" {
  for_each = var.zones

  lifecycle {
    postcondition {
      condition = contains(data.aws_availability_zones.list.names, each.key)
      error_message = <<-EOT
      Region: ${var.region}
      Zone: ${each.key}
      Choose from the following zones for this region: ${jsonencode(data.aws_availability_zones.list.names)}
      EOT
    }
  }
}
