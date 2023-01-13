output "value" {
  value = var.spec
}

output "region_zone_networks" {
  value = {
    for region, region_spec in var.spec.regions : region => {
      for zone, network in region_spec.zones :
      zone => network
    }
  }
}

output "region_machines" {
  value = {
    for name, machine_spec in var.spec.machines : machine_spec.region => {
      name = name
      spec = machine_spec
    }...
  }
}

output "region_databases" {
  value = {
    for name, database_spec in var.spec.databases : database_spec.region => {
      name = name
      spec = database_spec
    }...
  }
}

output "region_alloys" {
  value = {
    for name, spec in var.spec.alloy : spec.region => {
      name = name
      spec = spec
    }...
  }
}

output "region_gke" {
  value = {
    for name, spec in var.spec.gke : spec.region => {
      name = name
      spec = spec
    }...
  }
}

output "hex_id" {
  value = random_id.apply.hex
}
