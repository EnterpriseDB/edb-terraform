output "base" {
  value = var.spec
}

output "private_key" {
  value = var.spec.ssh_key.private_path != null ? file(var.spec.ssh_key.private_path) : tls_private_key.default[0].private_key_openssh
}

output "public_key" {
  value = var.spec.ssh_key.public_path != null ? file(var.spec.ssh_key.public_path) : tls_private_key.default[0].public_key_openssh
}

locals {
  # Extend machine's count as of list objects, with an index in the name only when count over 1
  machines_extended = flatten([
    for name, machine_spec in var.spec.machines : [
      for index in range(machine_spec.count) : {
        name = machine_spec.count > 1 ? "${name}-${index}" : name
        spec = merge(machine_spec, {
          # spec project tags
          tags = merge(var.spec.tags, machine_spec.tags, {
            # machine module specific tags
            name = machine_spec.count > 1 ? "${name}-${index}" : name
            id   = random_id.apply.hex
          })
          # assign operating system from mapped names
          operating_system = var.spec.images[machine_spec.image_name]
          # assign zone from mapped names
          zone = var.spec.regions[machine_spec.region].zones[machine_spec.zone_name].zone
          cidr = var.spec.regions[machine_spec.region].zones[machine_spec.zone_name].cidr
        })
      }
    ]
  ])
}

output "region_machines" {
  value = {
    for machine in local.machines_extended : 
      machine.spec.region => machine...
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
          name = name
          id   = random_id.apply.hex
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

output "region_zone_networks" {
  value = {
    for region, region_spec in var.spec.regions : region => {
      for name, values in region_spec.zones:
        name => values
    }
  }
}

output "region_cidrblocks" {
  description = "list of all cidrs from each defined zone"
  value = flatten([
    for region, values in var.spec.regions:
      values.cidr_block
  ])
}

output "region_ports" {
  description = "mapping of region to its list of port rules"
  value = {
    for region, values in var.spec.regions:
      region => flatten([values.service_ports, values.region_ports])
  }
}
