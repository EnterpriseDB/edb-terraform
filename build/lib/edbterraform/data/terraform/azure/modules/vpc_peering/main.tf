resource "azurerm_virtual_network_peering" "peering" {
  name                      = var.peering_name
  resource_group_name       = var.resource_name
  virtual_network_name      = var.network_name
  remote_virtual_network_id = var.peer_network_id
}
