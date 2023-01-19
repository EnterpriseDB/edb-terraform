variable "aurora" {}
variable "vpc_id" {}
variable "custom_security_group_id" {}
variable "cluster_name" {}
variable "created_by" {}
variable "name_id" { default = "0" }
variable "publicly_accessible" {
  type     = bool
  default  = true
  nullable = false
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
  }
}

data "aws_subnets" "ids" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

resource "aws_db_subnet_group" "aurora" {
  name       = format("rds-subnet-group-aurora-%s-%s", var.name_id, var.aurora.name)
  subnet_ids = tolist(data.aws_subnets.ids.ids)

  tags = {
    Name       = format("%s-%s", var.cluster_name, "aurora")
    Created_By = var.created_by
  }
}

resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier     = "${lower(var.cluster_name)}-${var.name_id}"
  engine                 = var.aurora.spec.engine
  engine_version         = var.aurora.spec.engine_version
  engine_mode            = "provisioned"
  database_name          = var.aurora.spec.dbname
  master_username        = var.aurora.spec.username
  master_password        = var.aurora.spec.password
  port                   = var.aurora.spec.port
  db_subnet_group_name   = aws_db_subnet_group.aurora.id
  availability_zones     = var.aurora.spec.zones
  apply_immediately      = true
  skip_final_snapshot    = true
  vpc_security_group_ids = [var.custom_security_group_id]

  tags = {
    Name       = format("%s-%s", var.cluster_name, "aurora-cluster")
    Created_By = var.created_by
  }
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  count = var.aurora.spec.count

  cluster_identifier      = aws_rds_cluster.aurora_cluster.id
  instance_class          = var.aurora.spec.instance_type
  engine                  = aws_rds_cluster.aurora_cluster.engine
  engine_version          = aws_rds_cluster.aurora_cluster.engine_version
  db_subnet_group_name    = aws_db_subnet_group.aurora.id
  db_parameter_group_name = aws_db_parameter_group.aurora_db_params.id
  apply_immediately       = true
  publicly_accessible     = var.publicly_accessible

  tags = {
    Name       = format("%s-%s-%s", var.cluster_name, "aurora-instance", count.index)
    Created_By = var.created_by
  }
}

resource "aws_db_parameter_group" "aurora_db_params" {
  name   = format("db-parameter-group-aurora-%s-%s", var.name_id, lower(var.aurora.name))
  family = format("%s%s", var.aurora.spec.engine, var.aurora.spec.engine_version)

  dynamic "parameter" {
    for_each = { for i, v in lookup(var.aurora.spec, "settings", []) : i => v }
    content {
      apply_method = "pending-reboot"
      name         = parameter.value.name
      value        = parameter.value.value
    }
  }

  tags = {
    Name       = format("%s-%s", var.cluster_name, "rds-aurora")
    Created_By = var.created_by
  }
}
