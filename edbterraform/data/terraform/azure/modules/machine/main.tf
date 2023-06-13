/*
https://github.com/hashicorp/terraform-provider-azurerm/issues/10167
data "azurerm_ssh_public_key" "main" {
  name                = var.public_key_name
  resource_group_name = var.resource_name
}
*/
resource "azurerm_public_ip" "main" {
  name                = "ip-${var.name}-${var.name_id}"
  resource_group_name = var.resource_name
  location            = var.machine.region
  allocation_method   = "Static"
  zones               = local.zones
  sku                 = local.public_ip_sku
  tags                = var.tags
}

resource "azurerm_network_interface" "internal" {
  name                = "internal-${var.name}-${var.name_id}"
  resource_group_name = var.resource_name
  location            = var.machine.region
  tags                = var.tags
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
  name                = format("%s-%s-%s", var.cluster_name, var.name, var.name_id)
  resource_group_name = var.resource_name
  location            = var.machine.region
  zone                = var.machine.zone
  size                = var.machine.instance_type

  admin_username = var.operating_system.ssh_user
  admin_ssh_key {
    username   = var.operating_system.ssh_user
    public_key = var.public_key
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

  tags = var.tags

  depends_on = [azurerm_network_interface.internal, ]
}

module "machine_ports" {
  source = "../security"

  security_group_name = var.security_group_name
  name_id          = "${var.name}-${var.name_id}"
  region           = var.machine.region
  resource_name    = var.resource_name
  ports            = var.ports
  ingress_cidrs    = flatten([azurerm_linux_virtual_machine.main.public_ip_address, azurerm_linux_virtual_machine.main.private_ip_addresses])  
  egress_cidrs     = flatten([azurerm_linux_virtual_machine.main.public_ip_address, azurerm_linux_virtual_machine.main.private_ip_addresses])
  tags             = var.tags
}

resource "null_resource" "ensure_ssh_open" {
  count = local.additional_volumes_count
  triggers = {
    "depends_on" = can(module.machine_ports) ? local.additional_volumes_length : local.additional_volumes_length
  }

  provisioner "remote-exec" {
    inline = [
      "echo connected",
    ]
    connection {
      type        = "ssh"
      user        = var.operating_system.ssh_user
      host        = azurerm_linux_virtual_machine.main.public_ip_address
      port        = var.machine.ssh_port
      agent       = var.use_agent # agent and private_key conflict
      private_key = var.use_agent ? null : var.private_key
    }
  }
}

resource "azurerm_managed_disk" "volume" {
  for_each = local.additional_volumes_map

  name                 = format("%s-%s-%s-%s", var.name, var.cluster_name, var.name_id, each.key)
  resource_group_name  = var.resource_name
  location             = var.machine.region
  zone                 = var.machine.zone
  storage_account_type = each.value.type
  create_option        = "Empty"
  disk_size_gb         = each.value.size_gb
  disk_iops_read_write = each.value.iops
  # Implicit dependency to aws_ebs_volume.ebs_volume
  tags = can(null_resource.ensure_ssh_open) ? var.tags : var.tags
  lifecycle {
    precondition {
      condition = (
        each.value.type != local.premium_ssd.value ||
        contains(local.premium_ssd.regions, var.machine.region)
      )
      error_message = <<-EOT
      ${var.name} not a valid configuration.
      Premium SSD v2 only availiable in: ${jsonencode(local.premium_ssd.regions)}
      For more information visit:
      https://learn.microsoft.com/en-us/azure/virtual-machines/disks-types#regional-availability
      EOT
    }
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "attached_volumes" {
  for_each = local.additional_volumes_map

  virtual_machine_id = azurerm_linux_virtual_machine.main.id
  managed_disk_id    = azurerm_managed_disk.volume[each.key].id
  lun                = 10 + tonumber(each.key)
  caching            = can(azurerm_managed_disk.volume) ? each.value.caching : each.value.caching
}

resource "null_resource" "copy_setup_volume_script" {
  count = local.additional_volumes_count
  triggers = {
    "depends_on" = local.additional_volumes_length
  }

  provisioner "file" {
    content     = file("${abspath(path.module)}/setup_volume.sh")
    destination = "/tmp/setup_volume.sh"

    connection {
      # Implicit dependency to null_resource.attached_volume
      type        = can(azurerm_virtual_machine_data_disk_attachment.attached_volumes) ? "ssh" : "ssh"
      user        = var.operating_system.ssh_user
      host        = azurerm_linux_virtual_machine.main.public_ip_address
      port        = var.machine.ssh_port
      agent       = var.use_agent # agent and private_key conflict
      private_key = var.use_agent ? null : var.private_key
    }
  }
}

resource "null_resource" "setup_volume" {
  for_each = local.additional_volumes_map
  provisioner "remote-exec" {
    inline = [
      "chmod a+x /tmp/setup_volume.sh",
      "/tmp/setup_volume.sh ${element(local.string_device_names, tonumber(each.key))} ${each.value.mount_point} ${length(var.additional_volumes) + 1}  >> /tmp/mount.log 2>&1"
    ]

    connection {
      # Implicit dependency to null_resource.copy_setup_volume_script
      type        = can(null_resource.copy_setup_volume_script) ? "ssh" : "ssh"
      user        = var.operating_system.ssh_user
      host        = azurerm_linux_virtual_machine.main.public_ip_address
      port        = var.machine.ssh_port
      agent       = var.use_agent # agent and private_key conflict
      private_key = var.use_agent ? null : var.private_key
    }
  }
}

