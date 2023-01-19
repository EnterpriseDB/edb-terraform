output "instance_type" {
  value = aws_instance.machine.instance_type
}

output "type" {
  value = var.machine.spec.type
}

output "zone" {
  value = var.machine.spec.zone
}

output "region" {
  value = var.machine.spec.region
}

output "public_ip" {
  value = aws_instance.machine.public_ip
}

output "private_ip" {
  value = aws_instance.machine.private_ip
}

output "public_dns" {
  value = aws_instance.machine.public_dns
}

output "tags" {
  value = aws_instance.machine.tags_all
}
