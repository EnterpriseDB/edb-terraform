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

locals {
  # Extend machine's count as of list objects with an index in the name
  machines_extended = flatten([
    for name, machine_spec in var.spec.machines: [
      for index in range(machine_spec.count): {
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
          name = format("%s-%s", var.spec.tags.cluster_name, machine.name)
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
          # database module specific tags
          name = format("%s-%s", var.spec.tags.cluster_name, name)
        })
      })
    }...
  }
}

output "region_auroras" {
  value = {
    for name, aurora_spec in var.spec.aurora : aurora_spec.region => {
      name = name
      spec = merge(aurora_spec, {
        # spec project tags
        tags = merge(var.spec.tags, aurora_spec.tags, {
          # aurora module specific tags
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
