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
      spec = merge(machine_spec, {
        # spec project tags
        tags = merge(var.spec.tags, machine_spec.tags, {
          # machine module specific tags
          name = format("%s-%s", var.spec.tags.cluster_name, name)
        })
      })
    }...
  }
}

output "region_kubernetes" {
  value = {
    for name, spec in var.spec.kubernetes : spec.region => {
      name = name
      spec = merge(spec, {
        # spec project tags
        tags = merge(var.spec.tags, spec.tags, {
          # kubernetes module specific tags
          name = format("%s-%s", var.spec.tags.cluster_name, name)
        })
      })
    }...
  }
}

output "hex_id" {
  value = random_id.apply.hex
}

output "pet_name" {
  value = random_pet.name.id
}
