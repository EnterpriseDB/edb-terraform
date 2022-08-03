output "machine_ips" {
  value = {
    type       = var.machine.spec.type
    az         = var.machine.spec.az
    region     = var.machine.spec.region
    private_ip = aws_instance.machine.private_ip
    public_ip  = aws_instance.machine.public_ip
    public_dns = aws_instance.machine.public_dns
  }
}
