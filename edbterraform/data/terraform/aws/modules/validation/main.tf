# Data sources run during plan
# UNLESS it relies on value which is known after apply 
# Validation locations by preference:
# 1. Inside of own module and executes during plan
# 2. Inside of specification module and executes during plan
# 3. Inside of validation module and executes during apply
variable "region" {}
variable "zones" {}

# availability data depends on providers region
data "aws_availability_zones" "zone_check" {
  all_availability_zones = true
  filter {
    name   = "state"
    values = ["available"]
  }

  lifecycle {
    postcondition {
      condition = alltrue([
        for zone in var.zones :
        contains(self.names, zone)
      ])
      error_message = (
        <<-EOT
Region:
  ${var.region}
Invalid Zones:
%{for zone in keys(var.zones)~}
%{if !contains(self.names, zone)~}
  ${zone}
%{endif~}
%{endfor~}
Valid Zone options:
  ${jsonencode(self.names)}
EOT
      )
    }
  }
}
