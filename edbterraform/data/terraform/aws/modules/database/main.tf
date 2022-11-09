variable "database" {}
variable "vpc_id" {}
variable "custom_security_group_id" {}
variable "cluster_name" {}
variable "created_by" {}

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

resource "aws_db_subnet_group" "rds" {
  name       = format("rds-subnet-group-rds-%s", var.database.name)
  subnet_ids = tolist(data.aws_subnets.ids.ids)

  tags = {
    Name       = format("%s-%s", var.cluster_name, "rds")
    Created_By = var.created_by
  }
}

resource "aws_db_instance" "rds_server" {
  backup_retention_period = 0
  db_subnet_group_name    = aws_db_subnet_group.rds.id
  engine                  = var.database.spec.engine
  engine_version          = var.database.spec.engine_version
  identifier              = var.database.name
  instance_class          = var.database.spec.instance_type
  multi_az                = false
  db_name                 = var.database.spec.dbname
  parameter_group_name    = aws_db_parameter_group.edb_rds_db_params.name
  username                = var.database.spec.username
  password                = var.database.spec.password
  port                    = var.database.spec.port
  publicly_accessible     = true
  allocated_storage       = var.database.spec.volume.size_gb
  storage_encrypted       = var.database.spec.volume.encrypted
  storage_type            = var.database.spec.volume.type
  iops                    = var.database.spec.volume.type == "io1" ? var.database.spec.volume.iops : null
  vpc_security_group_ids  = [var.custom_security_group_id]
  skip_final_snapshot     = true

  tags = {
    Name       = format("%s-%s", var.cluster_name, "rds")
    Created_By = var.created_by
  }
}

resource "aws_db_parameter_group" "edb_rds_db_params" {
  name   = format("db-parameter-group-rds-%s", lower(var.database.name))
  family = format("%s%s", var.database.spec.engine, var.database.spec.engine_version)

  dynamic "parameter" {
    for_each = { for i, v in lookup(var.database.spec, "settings", []) : i => v }
    content {
      apply_method = "pending-reboot"
      name         = parameter.value.name
      value        = parameter.value.value
    }
  }

  tags = {
    Name       = format("%s-%s", var.cluster_name, "rds")
    Created_By = var.created_by
  }
}
