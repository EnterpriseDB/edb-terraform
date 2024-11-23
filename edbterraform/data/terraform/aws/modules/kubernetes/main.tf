data "aws_availability_zones" "available" {}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.9.0"

  name                 = var.vpcAndClusterPrefix
  cidr                 = var.vpcCidr
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = [var.privateSubnet1, var.privateSubnet2, var.privateSubnet3]
  public_subnets       = [var.publicSubnet1, var.publicSubnet2, var.publicSubnet3]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.vpcAndClusterPrefix}" = "shared"
    "kubernetes.io/role/elb"                           = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.vpcAndClusterPrefix}" = "shared"
    "kubernetes.io/role/internal-elb"                  = "1"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.2.2"

  cluster_name    = var.vpcAndClusterPrefix
  cluster_version = var.clusterVersion
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
}
