module "key_pair_{{ region_ }}" {
  source = "./modules/key_pair"

  cluster_name = var.cluster_name
  ssh_pub_key  = var.ssh_pub_key

  providers = {
    aws = aws.{{ region_ }}
  }
}
