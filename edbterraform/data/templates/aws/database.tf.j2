module "database_{{ region_ }}" {
  source = "./modules/database"

  for_each = { for rm in lookup(local.region_databases, "{{ region }}", []) : rm.name => rm }

  vpc_id                   = module.vpc_{{ region_ }}.vpc_id
  database                 = each.value
  cluster_name             = var.cluster_name
  custom_security_group_id = module.security_{{ region_ }}.aws_security_group_id
  created_by               = var.created_by

  depends_on = [module.security_{{ region_ }}]

  providers = {
    aws = aws.{{ region_ }}
  }
}
