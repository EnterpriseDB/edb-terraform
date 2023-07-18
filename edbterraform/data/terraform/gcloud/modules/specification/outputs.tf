locals {
  tags = merge(var.spec.tags, {
    # add ids for tracking
    terraform_hex   = random_id.apply.hex
    terraform_id    = random_id.apply.id
    terraform_time  = time_static.first_created.id
    created_by      = local.created_by
    cluster_name    = local.cluster_name
  })
}

output "base" {
  value = merge(var.spec, {
    "tags" = local.tags
  })
}

output "tags" {
  value = local.tags
}

output "private_key" {
  value = var.spec.ssh_key.private_path != null ? file(var.spec.ssh_key.private_path) : try(tls_private_key.default[0].private_key_openssh, "")
}

output "public_key" {
  value = var.spec.ssh_key.public_path != null ? file(var.spec.ssh_key.public_path) : try(tls_private_key.default[0].public_key_openssh, "")
}

locals {
  # Extend machine's count as of list objects, with an index in the name only when count over 1
  machines_extended = flatten([
    for name, machine_spec in var.spec.machines : [
      for index in range(machine_spec.count) : {
        name = machine_spec.count > 1 ? "${name}-${index}" : name
        spec = merge(machine_spec, {
          # spec project tags
          tags = merge(local.tags, machine_spec.tags, {
            # machine module specific tags
            name = machine_spec.count > 1 ? "${name}-${index}" : name
          })
          # assign operating system from mapped names
          # add private and public key paths so they can be passed in the machine outputs
          operating_system = merge(var.spec.images[machine_spec.image_name], { "ssh_private_key_file": local.private_ssh_path, "ssh_public_key_file": local.public_ssh_path })
          # assign zone from mapped names
          zone = var.spec.regions[machine_spec.region].zones[machine_spec.zone_name].zone
        })
      }
    ]
  ])
}

output "region_machines" {
  value = {
    for machine in local.machines_extended:
      machine.spec.region => machine... 
  }
}

output "region_databases" {
  value = {
    for name, database_spec in var.spec.databases : database_spec.region => {
      name = name
      spec = merge(database_spec, {
        # spec project tags
        tags = merge(local.tags, database_spec.tags, {
          # databases module specific tags
          name = name
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
        tags = merge(local.tags, spec.tags, {
          # alloys module specific tags
          name = name
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

output "region_zone_networks" {
  value = {
    for region, region_spec in var.spec.regions : region => {
      for name, values in region_spec.zones :
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
