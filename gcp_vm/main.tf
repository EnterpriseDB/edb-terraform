locals {
  region_az_networks = {
    for region, region_spec in var.regions: region => {
      for az, network in try(region_spec.azs, {}): az => network
    }
  }
  region_machines = {
    for name, machine_spec in var.machines: machine_spec.region => {
      name = name
      spec = machine_spec
    }...
  }
  region_databases = {
    for name, database_spec in var.databases: database_spec.region => {
      name = name
      spec = database_spec
    }...
  }
  region_alloys = {
    for name, spec in var.alloy: spec.region => {
      name = name
      spec = spec
    }...
  }
}

resource "random_id" "apply" {
  byte_length = 4
}


module "vpc_us_west2"{
  source = "./modules/vpc"

  network_name = "${var.vpc_tag}-us-west2-${random_id.apply.hex}"

  providers = {
    google = google.us_west2
  }
}

module "network_us_west2" {
  source = "./modules/network"

  for_each = lookup(local.region_az_networks, "us-west2", null)

  network_name    = module.vpc_us_west2.vpc_id
  ip_cidr_range   = each.value
  name            = "us-west2-${each.key}-${random_id.apply.hex}"

  depends_on = [module.vpc_us_west2]

  providers = {
    google = google.us_west2
  }
}

module "service_connection_us_west2" {
  source = "./modules/service_connection"

  # Creates a single service connection,
  # if region has dbaas
  for_each = (
    contains(keys(merge(local.region_databases, local.region_alloys)), "us-west2") ? 
      toset([ "us-west2" ]) : toset([])
  )

  name = "us-west2-${random_id.apply.hex}"
  network = module.vpc_us_west2.vpc_id

  depends_on = [local.region_databases, module.network_us_west2]
  
  providers = {
    google = google.us_west2
  }
}

# Not Implemented, using defaults provided by terraform/gcloud
/*
module "routes_us_west2"{
  source = "./modules/routes"
}
*/

module "security_us_west2" {
  source = "./modules/security"

  network_name  = module.vpc_us_west2.vpc_id

  service_name = "service-us-west2-${random_id.apply.hex}"
  service_ports    = lookup(lookup(var.regions, "us-west2", null), "service_ports", [])
  public_cidrblock = var.public_cidrblock

  region_name = "region-us-west2-${random_id.apply.hex}"
  region_ports = lookup(lookup(var.regions, "us-west2", null), "region_ports", [])
  region_cidrblocks = flatten([
    for region in try(var.regions, []) : [
      for ip_cidr in try(region.azs, []) : ip_cidr
      ] 
    ])

  depends_on = [module.service_connection_us_west2]

  providers = {
    google = google.us_west2
  }
}





resource "local_file" "servers_yml" {
  filename        = "${abspath(path.root)}/servers.yml"
  file_permission = "0600"
  content         = <<-EOT
---
servers:
    EOT
}

