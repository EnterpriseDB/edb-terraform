output "subnet_id" {
  value = azurerm_subnet.internal.id
}

output "security_group_id" {
  value = azurerm_network_security_group.firewall.id
}

output "security_group_name" {
  value = azurerm_network_security_group.firewall.name
}
