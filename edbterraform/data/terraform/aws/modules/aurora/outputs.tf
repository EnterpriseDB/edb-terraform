output "region" {
  value = var.aurora.spec.region
}

output "username" {
  value = aws_rds_cluster.aurora_cluster.master_username
}

output "password" {
  value = aws_rds_cluster.aurora_cluster.master_password
}

output "private_ip" {
  value = var.publicly_accessible ? null : aws_rds_cluster.aurora_cluster.endpoint
}

output "public_ip" {
  value = var.publicly_accessible ? aws_rds_cluster.aurora_cluster.endpoint : null
}

output "port" {
  value = aws_rds_cluster.aurora_cluster.port
}

output "engine" {
  value = aws_rds_cluster.aurora_cluster.engine
}

output "version" {
  value = aws_rds_cluster.aurora_cluster.engine_version_actual
}

output "dbname" {
  value = aws_rds_cluster.aurora_cluster.database_name
}

output "instance_type" {
  value = aws_rds_cluster.aurora_cluster.db_cluster_instance_class
}

output "tags" {
  value = aws_rds_cluster.aurora_cluster.tags_all
}
