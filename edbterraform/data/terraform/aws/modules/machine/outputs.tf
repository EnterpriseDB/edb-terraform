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

output "additional_volumes" {
  value = var.machine.spec.additional_volumes
}

output "block_devices" {
  value = {
    initial = local.initial_block_devices
    all = local.all_block_devices
    final = local.final_block_devices
  }
}

output "operating_system" {
  value = var.operating_system
}

output "resource_id" {
  value = aws_instance.machine.id
}
