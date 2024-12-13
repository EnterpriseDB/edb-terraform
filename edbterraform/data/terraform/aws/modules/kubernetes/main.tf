data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.9.0"

  name                 = local.vpc_name
  cidr                 = var.vpcCidr
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = [var.privateSubnet1, var.privateSubnet2, var.privateSubnet3]
  public_subnets       = [var.publicSubnet1, var.publicSubnet2, var.publicSubnet3]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"                           = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"                  = "1"
  }

  tags = var.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.2.2"

  cluster_name    = local.name
  cluster_version = var.cluster_version
  subnet_ids      = module.vpc.private_subnets

  vpc_id = module.vpc.vpc_id

  eks_managed_node_groups = {
    first = {
      desired_capacity = var.desiredCapacity
      max_capacity     = var.maxCapacity
      min_capacity     = var.minCapacity

      instance_type = var.instanceType
    }
  }

  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access = local.public_access
  cluster_endpoint_public_access_cidrs = local.public_access_cidrs

  tags = var.tags
}

# Defer data read until the cluster is created
data "aws_eks_cluster" "cluster" {
  name = can(module.eks) ? module.eks.cluster_name : module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = can(module.eks) ? module.eks.cluster_name : module.eks.cluster_name
}
