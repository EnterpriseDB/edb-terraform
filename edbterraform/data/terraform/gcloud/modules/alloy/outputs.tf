output "ips" {
  value = {
    region   = var.aurora.spec.region
    username = aws_rds_cluster.aurora_cluster.master_username
    password = aws_rds_cluster.aurora_cluster.master_password
    address  = aws_rds_cluster.aurora_cluster.endpoint
    port     = var.alloy.spec.port
    dbname   = var.alloy.spec.dbname
  }
}
