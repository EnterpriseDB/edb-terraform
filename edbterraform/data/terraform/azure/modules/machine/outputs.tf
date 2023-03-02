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
  value = {
    for k,v in local.mapped_volumes:
      k=>length(toolbox_external.get_uuid) > 0 ? merge(v,{"uuid":toolbox_external.get_uuid.0.result[k]}) : v
  }
}

output "operating_system" {
  value = var.operating_system
}
