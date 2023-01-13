output "value" {
  value = var.spec
}

output "region_zone_networks" {
  value = {
    for region, spec in var.spec.regions : region => {
      for zone, network in spec.zones :
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

output "region_auroras" {
  value = {
    for name, aurora_spec in var.spec.aurora : aurora_spec.region => {
      name = name
      spec = aurora_spec
    }...
  }
}

output "hex_id" {
  value = random_id.apply.hex
}
