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

locals {
  # Extend machine's count as of list objects with an index in the name
  machines_extended = flatten([
    for name, machine_spec in var.spec.machines : [
      for index in range(machine_spec.count) : {
        name = "${name}-${index}"
        spec = machine_spec
      }
    ]
  ])
}

output "region_machines" {
  value = {
    for machine in local.machines_extended : machine.spec.region => {
      name = machine.name
      spec = merge(machine.spec, {
        # spec project tags
        tags = merge(var.spec.tags, machine.spec.tags, {
          # machine module specific tags
          name = machine.name
          id   = random_id.apply.hex
        })
      })
    }...
  }
}

output "region_databases" {
  value = {
    for name, database_spec in var.spec.databases : database_spec.region => {
      name = name
      spec = merge(database_spec, {
        # spec project tags
        tags = merge(var.spec.tags, database_spec.tags, {
          # databases module specific tags
          name = name
          id   = random_id.apply.hex
        })
      })
    }...
  }
}

output "region_alloys" {
  value = {
    for name, spec in var.spec.alloy : spec.region => {
      name = name
      spec = merge(spec, {
        # spec project tags
        tags = merge(var.spec.tags, spec.tags, {
          # alloys module specific tags
          name = name
          id   = random_id.apply.hex
        })
      })
    }...
  }
}

output "region_kubernetes" {
  value = {
    for name, spec in var.spec.kubernetes : spec.region => {
      name = name
      spec = merge(spec, spec.tags, {
        # spec project tags
        tags = merge(var.spec.tags, {
          # kubernetes module specific tags
          name = name
          id   = random_id.apply.hex
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
