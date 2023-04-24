output "instance_type" {
  value = azurerm_postgresql_flexible_server.instance[0].sku_name
}
output "dbname" {
  value = var.dbname
}
output "region" {
  value = azurerm_postgresql_flexible_server.instance[0].location
}
output "domain" {
  value = azurerm_postgresql_flexible_server.instance[0].fqdn
}
output "public_ip" {
  value = (
    azurerm_postgresql_flexible_server.instance[0].public_network_access_enabled ?
      azurerm_postgresql_flexible_server.instance[0].fqdn : ""
    )
}
output "private_ip" {
  value = azurerm_postgresql_flexible_server.instance[0].fqdn
}
output "username" {
  value = azurerm_postgresql_flexible_server.instance[0].administrator_login
}
output "password" {
  value = azurerm_postgresql_flexible_server.instance[0].administrator_password
}
output "engine" {
  value = var.engine
}
output "version" {
  value = azurerm_postgresql_flexible_server.instance[0].version
}
output "tags" {
  value = azurerm_postgresql_flexible_server.instance[0].tags
}
