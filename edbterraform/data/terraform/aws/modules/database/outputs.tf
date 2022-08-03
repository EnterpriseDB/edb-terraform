output "database_ips" {
  value = {
    region      = var.database.spec.region
    username    = aws_db_instance.rds_server.username
    password    = var.database.spec.password
    address     = aws_db_instance.rds_server.address
    port        = aws_db_instance.rds_server.port
    dbname      = aws_db_instance.rds_server.name
  }
}
