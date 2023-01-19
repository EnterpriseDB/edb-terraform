
resource "azurerm_resource_group" "rg" {
  location = var.resourceGroupLocation != null ? var.resourceGroupLocation : var.region
  name     = var.resourceGroupName
}

resource "azurerm_log_analytics_workspace" "wrkspc" {
  location            = var.logAnalyticsWorkspaceLocation != null ? var.logAnalyticsWorkspaceLocation : var.region
  name                = var.logAnalyticsWorkspaceName
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = var.logAnalyticsWorkspaceSku
}

resource "azurerm_log_analytics_solution" "solution" {
  location              = azurerm_log_analytics_workspace.wrkspc.location
  resource_group_name   = azurerm_resource_group.rg.name
  solution_name         = var.solutionName
  workspace_name        = azurerm_log_analytics_workspace.wrkspc.name
  workspace_resource_id = azurerm_log_analytics_workspace.wrkspc.id

  plan {
    product   = var.solutionName
    publisher = var.publisherName
  }
}

resource "azurerm_kubernetes_cluster" "k8s" {
  location            = azurerm_resource_group.rg.location
  name                = var.cluster_name
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.cluster_name
  tags                = var.tags

  default_node_pool {
    name       = "agentpool"
    vm_size    = var.vmSize
    node_count = var.nodeCount
  }
  linux_profile {
    admin_username = var.ssh_user

    ssh_key {
      key_data = file(var.sshPublicKey)
    }
  }
  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }
  service_principal {
    client_id     = var.aksServicePrincipalAppId
    client_secret = var.aksServicePrincipalClientSecret
  }
}

