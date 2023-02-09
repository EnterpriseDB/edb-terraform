output "base" {
  value = var.spec
}

output "private_key" {
  value = var.spec.ssh_key.private_path != null ? file(var.spec.ssh_key.private_path) : tls_private_key.default[0].private_key_openssh
}

output "public_key" {
  value = var.spec.ssh_key.public_path != null ? file(var.spec.ssh_key.public_path) : tls_private_key.default[0].public_key_openssh
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
  # Extend machine's count as of list objects, with an index in the name only when count over 1
  machines_extended = flatten([
    for name, machine_spec in var.spec.machines : [
      for index in range(machine_spec.count) : {
        name = machine_spec.count > 1 ? "${name}-${index}" : name
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

output "region_kubernetes" {
  value = {
    for name, spec in var.spec.kubernetes : spec.region => {
      name = name
      spec = merge(spec, {
        # spec project tags
        tags = merge(var.spec.tags, spec.tags, {
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
