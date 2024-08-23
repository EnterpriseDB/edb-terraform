locals {
  tags = merge(var.spec.tags, {
    # add ids for tracking
    terraform_hex   = random_id.apply.hex
    terraform_id    = random_id.apply.id
    terraform_time  = time_static.first_created.id
    created_by      = local.created_by
    cluster_name    = local.cluster_name
  })

  # each regions cidrblock, should not overlap since we perform VPC peering
  region_cidrblocks = flatten([
    for region, values in var.spec.regions:
      values.cidr_block
  ])

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
          # Use 'Name' tag to have instance name set for AWS UI
          Name = format("%s-%s-%s", (machine_spec.count > 1 ? "${name}-${index}" : name), local.cluster_name, random_id.apply.hex)
          })
          # assign operating system from mapped names
          # add private and public key paths so they can be passed in the machine outputs
          operating_system = merge(var.spec.images[machine_spec.image_name], { "ssh_private_key_file": local.private_ssh_path, "ssh_public_key_file": local.public_ssh_path })
          # assign zone from mapped names
          zone = var.spec.regions[machine_spec.region].zones[machine_spec.zone_name].zone
          cidr = var.spec.regions[machine_spec.region].zones[machine_spec.zone_name].cidr

          # expand any additional volumes with count > 1 and then merge the lists as a single list
          additional_volumes = length(machine_spec.additional_volumes) > 0 ? flatten([
            for volume in machine_spec.additional_volumes: [
              for index in range(volume.count): volume
            ]
          ]) : machine_spec.additional_volumes
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
        tags = merge(local.tags, database_spec.tags, {
          # database module specific tags
          Name = format("%s-%s-%s", name, local.cluster_name, random_id.apply.hex)
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
        tags = merge(local.tags, aurora_spec.tags, {
          # aurora module specific tags
          Name = format("%s-%s-%s", name, local.cluster_name, random_id.apply.id)
        })
      })
    }...
  }
}

output "biganimal" {
  value = {
    for name, biganimal_spec in var.spec.biganimal : name => merge(biganimal_spec, {
        project = {
          id = biganimal_spec.project.id == null || biganimal_spec.project.id == "" ? var.ba_project_id_default : biganimal_spec.project.id
        }
        image = var.ba_ignore_image_default ? { pg = null, proxy = null } : {
          pg    = biganimal_spec.image.pg == null || biganimal_spec.image.pg == "" ? var.ba_pg_image_default : biganimal_spec.image.pg
          proxy = biganimal_spec.image.proxy == null || biganimal_spec.image.proxy == "" ? var.ba_proxy_image_default : biganimal_spec.image.proxy
        }
        # spec project tags
        tags = merge(local.tags, biganimal_spec.tags, {
          # Biganimal reserves the Name tag
          # Name = format("%s-%s-%s", name, local.cluster_name, random_id.apply.id)
        })
        data_groups = {
          for data_group_name, data_group_spec in biganimal_spec.data_groups : data_group_name => merge(data_group_spec, {
            cloud_account = data_group_spec.cloud_account == null ? var.ba_cloud_account_default : data_group_spec.cloud_account
          })
        }
        witness_groups = {
          for witness_group_name, witness_group_spec in biganimal_spec.witness_groups : witness_group_name => merge(witness_group_spec, {
            cloud_account = witness_group_spec.cloud_account == null ? var.ba_cloud_account_default : witness_group_spec.cloud_account
          })
        }
    })
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
        tags = merge(local.tags, spec.tags, {
          # kubernetes module specific tags
          Name = format("%s-%s-%s", name, local.cluster_name, random_id.apply.id)
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
  value = local.region_cidrblocks
}

output "region_ports" {
  description = "mapping of region to its list of port rules"
  value = local.region_ports
}
