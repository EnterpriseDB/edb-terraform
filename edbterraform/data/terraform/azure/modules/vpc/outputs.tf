output "resource_name" {
  value = azurerm_resource_group.main.name
}

output "network_name" {
  value = azurerm_virtual_network.main.name
}

output "region" {
    value = azurerm_resource_group.main.location
}
