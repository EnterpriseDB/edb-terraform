output "instance_type" {
  value = azurerm_linux_virtual_machine.main.size
}
output "type" {
  value = var.machine.type
}
output "zone" {
  value = azurerm_linux_virtual_machine.main.zone
}
output "region" {
  value = azurerm_linux_virtual_machine.main.location
}
output "public_ip" {
  value = azurerm_linux_virtual_machine.main.public_ip_address
}
output "private_ip" {
  value = azurerm_linux_virtual_machine.main.private_ip_address
}
output "tags" {
  value = azurerm_linux_virtual_machine.main.tags
}

output "additional_volumes" {
  value = var.additional_volumes
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
