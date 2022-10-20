module "vpc_{{ region_ }}" {
  source = "./modules/vpc"

  vpc_cidr_block = lookup(lookup(var.regions, "{{ region }}"), "cidr_block")
  vpc_tag        = var.vpc_tag

  providers = {
    aws = aws.{{ region_ }}
  }
}

module "network_{{ region_ }}" {
  source = "./modules/network"

  for_each = lookup(local.region_az_networks, "{{ region }}", null)

  vpc_id             = module.vpc_{{ region_ }}.vpc_id
  public_subnet_tag  = var.public_subnet_tag
  cidr_block         = each.value
  availability_zone  = each.key

  depends_on = [module.vpc_{{ region_ }}]

  providers = {
    aws = aws.{{ region_ }}
  }
}

module "routes_{{ region_ }}" {
  source = "./modules/routes"

  subnet_count       = length([for a, s in lookup(local.region_az_networks, "{{ region }}", {}) : a])
  vpc_id             = module.vpc_{{ region_ }}.vpc_id
  project_tag        = var.project_tag
  public_cidrblock   = var.public_cidrblock
  cluster_name       = var.cluster_name

  depends_on = [module.network_{{ region_ }}]

  providers = {
    aws = aws.{{ region_ }}
  }
}

module "security_{{ region_ }}" {
  source = "./modules/security"

  vpc_id           = module.vpc_{{ region_ }}.vpc_id
  public_cidrblock = var.public_cidrblock
  project_tag      = var.project_tag
  service_ports    = lookup(lookup(var.regions, "{{ region }}", null), "service_ports", [])
  cluster_name     = var.cluster_name

  depends_on = [module.routes_{{ region_ }}]

  providers = {
    aws = aws.{{ region_ }}
  }
}
