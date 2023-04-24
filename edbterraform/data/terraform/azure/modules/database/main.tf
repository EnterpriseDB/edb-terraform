resource "azurerm_postgresql_flexible_server" "instance" {
  count = startswith(var.engine,"postgres") ? 1 : 0

  name                   = format("%s-%s",
    var.name,
    var.name_id
  )
  resource_group_name    = var.resource_name
  location               = var.region
  zone                   = var.zone
  version                = var.engine_version
  administrator_login    = var.username
  administrator_password = var.password
  storage_mb             = local.size_mb
  sku_name               = var.instance_type
  tags                   = var.tags

  create_mode = "Default"
  geo_redundant_backup_enabled = false
  authentication {
    password_auth_enabled = true
  }

}

/*
https://learn.microsoft.com/en-us/rest/api/sql/2021-02-01-preview/firewall-rules/create-or-update?tabs=HTTP#firewallrule
all Azure-internal IP addresses only, including client-made services
*/
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure-services" {
  name                   = format("%s-%s-azure-ips",
    var.name,
    var.name_id
  )
  server_id        = azurerm_postgresql_flexible_server.instance[0].id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "instance" {
  count = var.public_access ? 1 : 0
  name                   = format("%s-%s-public-access",
    var.name,
    var.name_id
  )
  server_id        = azurerm_postgresql_flexible_server.instance[0].id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

resource "azurerm_postgresql_flexible_server_configuration" "instance" {
  count     = length(var.settings)
  server_id = azurerm_postgresql_flexible_server.instance[0].id
  name      = var.settings[count.index].name
  value     = var.settings[count.index].value
}

resource "azurerm_postgresql_flexible_server_database" "instance" {
  count     = length(var.dbname) > 0 ? 1 : 0
  name      = var.dbname
  server_id = azurerm_postgresql_flexible_server.instance[0].id
  collation = "C"
  charset   = "utf8"
}
