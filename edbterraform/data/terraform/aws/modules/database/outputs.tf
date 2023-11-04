output "region" {
  value = var.database.spec.region
}

output "username" {
  value = aws_db_instance.rds_server.username
}

output "password" {
  value = var.database.spec.password
}

output "private_ip" {
  value = var.publicly_accessible ? null : aws_db_instance.rds_server.address
}

output "public_ip" {
  value = var.publicly_accessible ? aws_db_instance.rds_server.address : null
}

output "port" {
  value = aws_db_instance.rds_server.port
}

output "engine" {
  value = aws_db_instance.rds_server.engine
}

output "version" {
  value = aws_db_instance.rds_server.engine_version_actual
}

output "instance_type" {
  value = aws_db_instance.rds_server.instance_class
}

output "dbname" {
  value = aws_db_instance.rds_server.db_name
}

output "tags" {
  value = aws_db_instance.rds_server.tags_all
}

output "resource_id" {
  value = aws_db_instance.rds_server.identifier
}

output "resources" {
  value = {
    aws_db_subnet_group = { rds = aws_db_subnet_group.rds }
    aws_db_instance = {rds_server = aws_db_instance.rds_server }
    aws_db_parameter_group = { edb_rds_db_params = aws_db_parameter_group.edb_rds_db_params }
  }
}
