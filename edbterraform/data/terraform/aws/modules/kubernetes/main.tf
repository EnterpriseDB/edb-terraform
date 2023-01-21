data "aws_availability_zones" "available" {}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

locals {
  vpcAndClusterName = "${var.vpcAndClusterPrefix}-${random_string.suffix.result}"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.18.1"

  name                 = local.vpcAndClusterName
  cidr                 = var.vpcCidr
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = [var.privateSubnet1, var.privateSubnet2, var.privateSubnet3]
  public_subnets       = [var.publicSubnet1, var.publicSubnet2, var.publicSubnet3]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.vpcAndClusterName}" = "shared"
    "kubernetes.io/role/elb"                           = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.vpcAndClusterName}" = "shared"
    "kubernetes.io/role/internal-elb"                  = "1"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.30.3"

  cluster_name    = local.vpcAndClusterName
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
