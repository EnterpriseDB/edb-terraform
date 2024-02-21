locals {
  tags = merge(var.spec.tags, {
    # add ids for tracking
    terraform_hex   = random_id.apply.hex
    terraform_id    = random_id.apply.id
    terraform_time  = time_static.first_created.id
    created_by      = local.created_by
    cluster_name    = local.cluster_name
  })

  machine_ssh_ports = distinct([for machine, values in var.spec.machines: values.ssh_port])
  region_ssh_exists = {
    for region, values in var.spec.regions: region => anytrue([
      for port in values.ports: contains(local.machine_ssh_ports, coalesce(port.port, -2)) || contains(local.machine_ssh_ports, coalesce(port.to_port, -2)) if port.defaults == "service"
    ])
  }
  machine_ssh_rules = flatten([
    for port in local.machine_ssh_ports: [
      {
        "type": "ingress",
        "defaults": "service",
        "cidrs": [],
        "protocol": "tcp",
        "port": port,
        "to_port": port,
        "description": "Force SSH Access"
      },
      {
        "type": "egress",
        "defaults": "service",
        "cidrs": [],
        "protocol": "tcp",
        "port": port,
        "to_port": port,
        "description": "Force SSH Access"
      },
    ]
  ])

  # save ports per region
  region_ports = {
    for region, values in var.spec.regions: region => concat(values.ports, (local.region_ssh_exists[region] ? [] : local.machine_ssh_rules))
  }
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
          # Handle 0 as null to represent a region with no zones available
          zone = tostring(var.spec.regions[machine_spec.region].zones[machine_spec.zone_name].zone) == "0" ? null : var.spec.regions[machine_spec.region].zones[machine_spec.zone_name].zone

          # Azure networking does not allow fine-grain control like AWS security groups
          # The machine module defines a network interface security group so machines can define rules specific to the instance
          # This network interface security group has preference over the subnet security group
          # so it will not be attached when no ports are defined so that the subnets security group is used.
          ports = length(machine_spec.ports) != 0 ? flatten([local.region_ports[machine_spec.region], machine_spec.ports]) : machine_spec.ports
        })
      }
    ]
  ])
  region_machines = {
    for machine in local.machines_extended :
      machine.spec.region => machine...
  }
}

output "region_machines" {
  value = local.region_machines
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
        # assign zone from mapped names
        # Handle 0 as null to represent a region with no zones available
        zone = tostring(database_spec.zone) == "0" ? null : database_spec.zone
      })
    }...
  }
}

output "region_biganimals" {
  value = {
    for name, biganimal_spec in var.spec.biganimal : biganimal_spec.region => {
      name = name
      spec = merge(biganimal_spec, {
        # spec project tags
        tags = merge(local.tags, biganimal_spec.tags, {
          Name = format("%s-%s-%s", name, local.cluster_name, random_id.apply.id)
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
        tags = merge(local.tags, spec.tags, {
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
        # Handle 0 as null to represent a region with no zones available
        name => merge(values, {zone = tostring(values.zone) == "0" ? null : values.zone})
    }
  }
}

output "region_cidrblocks" {
  description = "list of all cidrs from each defined region"
  value = local.region_cidrblocks
}

output "region_ports" {
  description = "mapping of region to its list of port rules"
  value = local.region_ports
}
