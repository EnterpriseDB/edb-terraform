output "value" {
  value = var.spec
}

output "region_zone_networks" {
  value = {
    for region, region_spec in var.spec.regions: region => {
      for zone, network in region_spec.zones:
        zone => network
    }
  }
}

output "region_machines" {
  value = {
    for name, machine_spec in var.spec.machines: machine_spec.region => {
      name = name
      spec = machine_spec
    }...
  }  
}

output "hex_id" {
  value = random_id.apply.hex
}
