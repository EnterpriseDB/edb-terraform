data "azurerm_ssh_public_key" "main" {
  name                = var.public_key_name
  resource_group_name = var.resource_name
}

resource "azurerm_public_ip" "main" {
  name                = "ip-${var.machine.name}-${var.name_id}"
  resource_group_name = var.resource_name
  location            = var.region
  allocation_method   = "Static"
  zones               = local.zones
  sku                 = local.public_ip_sku
}

resource "azurerm_network_interface" "internal" {
  name                = "internal-${var.machine.name}-${var.name_id}"
  resource_group_name = var.resource_name
  location            = var.region

  ip_configuration {
    name                          = "internal"
    private_ip_address_version    = "IPv4"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.subnet_id
    public_ip_address_id          = azurerm_public_ip.main.id
  }

  depends_on = [azurerm_public_ip.main, ]
}

resource "azurerm_linux_virtual_machine" "main" {
  name                = format("%s-%s-%s", var.cluster_name, var.machine.name, var.name_id)
  resource_group_name = var.resource_name
  location            = var.region
  zone                = var.zone
  size                = var.machine.instance_type

  admin_username = var.ssh_user
  admin_ssh_key {
    username   = var.ssh_user
    public_key = data.azurerm_ssh_public_key.main.public_key
  }
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.internal.id]

  os_disk {
    caching              = var.machine.volume.caching
    storage_account_type = var.machine.volume.type
    disk_size_gb         = var.machine.volume.size_gb
  }

  additional_capabilities {
    ultra_ssd_enabled = local.ultra_ssd_enabled
  }

  plan {
    name      = var.operating_system.sku
    product   = var.operating_system.offer
    publisher = var.operating_system.publisher
  }

  source_image_reference {
    publisher = var.operating_system.publisher
    offer     = var.operating_system.offer
    sku       = var.operating_system.sku
    version   = var.operating_system.version
  }

  depends_on = [azurerm_network_interface.internal, ]
}

resource "azurerm_managed_disk" "volume" {
  for_each = local.additional_volumes

  name                 = format("%s-%s-%s-%s", var.machine.name, var.cluster_name, var.name_id, each.key)
  resource_group_name  = var.resource_name
  location             = var.region
  zone                 = var.zone
  storage_account_type = each.value.type
  create_option        = "Empty"
  disk_size_gb         = each.value.size_gb
  disk_iops_read_write = each.value.iops

  lifecycle {
    precondition {
      condition = (
        each.value.type != local.premium_ssd.value ||
        contains(local.premium_ssd.regions, var.region)
      )
      error_message = <<-EOT
      ${var.machine.name} not a valid configuration.
      Premium SSD v2 only availiable in: ${jsonencode(local.premium_ssd.regions)}
      For more information visit:
      https://learn.microsoft.com/en-us/azure/virtual-machines/disks-types#regional-availability
      EOT
    }
  }

  depends_on = [
    azurerm_linux_virtual_machine.main,
  ]
}

resource "azurerm_virtual_machine_data_disk_attachment" "attached_volumes" {
  for_each = local.additional_volumes

  virtual_machine_id = azurerm_linux_virtual_machine.main.id
  managed_disk_id    = azurerm_managed_disk.volume[each.key].id
  lun                = 10 + tonumber(each.key)
  caching            = each.value.caching

  depends_on = [
    azurerm_managed_disk.volume,
  ]
}

resource "null_resource" "copy_setup_volume_script" {
  count = local.volume_script_count

  provisioner "file" {
    content     = file("${abspath(path.module)}/setup_volume.sh")
    destination = "/tmp/setup_volume.sh"

    # Requires firewall access to ssh port
    connection {
      type        = "ssh"
      user        = var.ssh_user
      host        = azurerm_linux_virtual_machine.main.public_ip_address
      private_key = file(var.private_key)
    }
  }

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.attached_volumes,
  ]

}

resource "null_resource" "setup_volume" {
  for_each = local.additional_volumes

  provisioner "remote-exec" {
    inline = [
      "chmod a+x /tmp/setup_volume.sh",
      "/tmp/setup_volume.sh ${element(local.linux_device_names, tonumber(each.key))} ${each.value.mount_point} ${length(lookup(var.machine, "additional_volumes", [])) + 1}  >> /tmp/mount.log 2>&1"
    ]

    # Requires firewall access to ssh port
    connection {
      type        = "ssh"
      user        = var.ssh_user
      host        = azurerm_linux_virtual_machine.main.public_ip_address
      private_key = file(var.private_key)
    }
  }

  depends_on = [
    null_resource.copy_setup_volume_script
  ]
}
