data "google_compute_regions" "all" {
  # status defaults to UP and DOWN

  lifecycle {
    postcondition {
      # Check for all regions to be valid region options
      condition = alltrue([
        for region in keys(var.spec.regions) :
        contains(self.names, region)
      ])
      error_message = <<-EOT
Invalid Regions Set:
%{for region in keys(var.spec.regions)~}
%{if !contains(self.names, region)~}
    ${region}
%{endif~}
%{endfor~}
Valid Region Options:
  ${jsonencode(self.names)}
EOT
    }
  }
}

data "google_compute_regions" "unavailable" {
  status = "DOWN"

  lifecycle {
    postcondition {
      # Check if any region is an unavailable region
      condition = alltrue([
        for region in keys(var.spec.regions):
        !contains(self.names, region)
      ])
      error_message = <<-EOT
Unavailable Regions Set:
%{for region in keys(var.spec.regions)~}
%{if contains(self.names, region)~}
    ${region}
%{endif~}
%{endfor~}
Valid Region Options:
  ${jsonencode(setsubtract(data.google_compute_regions.all.names, self.names))}
EOT
    }
  }
}

data "google_compute_zones" "region" {
  for_each = var.spec.regions

  region = each.key
  # status defaults to all available zones
  lifecycle {
    postcondition {
      # Check for all zones in a region to be valid options
      condition = alltrue([
        for name, values in each.value.zones:
        contains(self.names, values.zone)
      ])
      error_message = <<-EOT
Region:
    ${each.key}
Invalid Zones Set:
%{for name, values in each.value.zones~}
%{if !contains(self.names, values.zone)~}
    ${name}: ${values.zone}
%{endif~}
%{endfor~}
Valid Zone Options:
    ${jsonencode(self.names)}
EOT
    }
  }
}

data "google_compute_zones" "unavailable" {
  for_each = var.spec.regions

  region = each.key
  status = "DOWN"

  lifecycle {
    postcondition {
      # Check if any zone is an unavailable zone
      condition = alltrue([
        for name, values in each.value.zones:
        !contains(self.names, values.zone)
      ])
      error_message = <<-EOT
Region:
    ${each.key}
Unavailable Zones Set:
%{for name, values in each.value.zones~}
%{if contains(self.names, values.zone)~}
    ${values.zone}
%{endif~}
%{endfor~}
Available Zone Options:
    ${jsonencode(setsubtract(data.google_compute_zones.region[each.key].names, self.names))}
EOT
    }
  }
}

resource "time_static" "first_created" {
}

resource "random_pet" "name" {
}
