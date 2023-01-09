module "machine_{{ region_ }}" {
  source = "./modules/machine"

  for_each = { for rm in lookup(local.region_machines, "{{ region }}", []) : rm.name => rm }

  operating_system         = var.operating_system
  vpc_id                   = module.vpc_{{ region_ }}.vpc_id
  cidr_block               = lookup(lookup(local.region_az_networks, "{{ region }}", null), each.value.spec.az, null)
  az                       = each.value.spec.az
  machine                  = each.value
  cluster_name             = var.cluster_name
  custom_security_group_id = module.security_{{ region_ }}.aws_security_group_id
  ssh_pub_key              = var.ssh_pub_key
  ssh_priv_key             = var.ssh_priv_key
  ssh_user                 = var.ssh_user
  created_by               = var.created_by
  key_name                 = module.key_pair_{{ region_ }}.key_pair_id

  depends_on = [module.key_pair_{{ region_ }}, module.security_{{ region_ }}]

  providers = {
    aws = aws.{{ region_ }}
  }
}
