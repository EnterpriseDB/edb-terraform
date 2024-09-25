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

  # https://learn.microsoft.com/en-us/azure/virtual-machines/user-data
  # https://learn.microsoft.com/en-us/azure/virtual-machines/custom-data
  # expects string to be base64 encoded
  user_data = var.machine.user_data == null ? var.machine.user_data : base64encode(var.machine.user_data)

  tags = var.tags

  depends_on = [azurerm_network_interface.internal, ]
}

resource "azurerm_network_security_group" "firewall" {
  count               = length(var.ports) != 0 ? 1 : 0
  name                = replace(join("-", formatlist("%#v", [var.name, var.machine.region, var.machine.zone, var.name_id])), "\"", "")
  resource_group_name = var.resource_name
  location            = var.machine.region
  tags                = var.tags
}

resource "azurerm_network_interface_security_group_association" "firewall" {
  count                = length(var.ports) != 0 ? 1 : 0
  network_interface_id = azurerm_network_interface.internal.id
  network_security_group_id = azurerm_network_security_group.firewall.0.id
}

module "machine_ports" {
  source = "../security"

  security_group_name = length(var.ports) != 0 ? azurerm_network_security_group.firewall.0.name : var.security_group_name
  name_id          = "${var.name}-${var.name_id}"
  region           = var.machine.region
  resource_name    = var.resource_name
  ports            = local.machine_ports
  public_cidrblocks = var.public_cidrblocks
  service_cidrblocks = var.service_cidrblocks
  internal_cidrblocks = var.internal_cidrblocks
  target_cidrblocks = formatlist("%s/32",[
    azurerm_linux_virtual_machine.main.public_ip_address,
    azurerm_linux_virtual_machine.main.private_ip_address,
  ])
  tags             = var.tags
  rule_offset      = 1000
}

resource "null_resource" "ensure_ssh_open" {
  count = local.additional_volumes_count
  triggers = {
    "depends0" = local.additional_volumes_length
    "depends1" = can(module.machine_ports)
  }

  provisioner "remote-exec" {
    inline = [
      "printf 'connected\n'",
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

resource "toolbox_external" "initial_block_devices" {
  count = local.additional_volumes_count
  query = {
    depend0 = can(null_resource.ensure_ssh_open)
    depends1 = local.additional_volumes_length
  }
  program = [
    "bash",
    "-c",
    "${abspath(path.module)}/lsblk_devices.sh '${var.operating_system.ssh_user}@${azurerm_linux_virtual_machine.main.public_ip_address} -p ${var.machine.ssh_port} -i ${var.operating_system.ssh_private_key_file}'",
  ]
}

locals {
  initial_block_devices = can(toolbox_external.initial_block_devices.0.result) ? jsondecode(base64decode(toolbox_external.initial_block_devices.0.result.base64json)) : {}
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
  # Implicit dependency
  tags = can(toolbox_external.initial_block_devices) ? var.tags : var.tags
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

resource "toolbox_external" "all_block_devices" {
  count = local.additional_volumes_count
  query = {
    depend0 = can(azurerm_virtual_machine_data_disk_attachment.attached_volumes)
    depends1 = local.additional_volumes_length
  }
  program = [
    "bash",
    "-c",
    "${abspath(path.module)}/lsblk_devices.sh '${var.operating_system.ssh_user}@${azurerm_linux_virtual_machine.main.public_ip_address} -p ${var.machine.ssh_port} -i ${var.operating_system.ssh_private_key_file}'",
  ]
}

locals {
  all_block_devices = can(toolbox_external.all_block_devices.0.result) ? jsondecode(base64decode(toolbox_external.all_block_devices.0.result.base64json)) : {}
}

locals {
  script_variables = [
    for key, values in local.additional_volumes_map: {
        "device_names": element(local.linux_device_names, tonumber(key))
        "number_of_volumes": length(var.additional_volumes) + 1
        "mount_point": values.mount_point
        "mount_options": coalesce(try(join(",", values.mount_options), null), try(join(",", local.mount_options), null))
        "filesystem": coalesce(values.filesystem, local.filesystem)
    }
  ]
}

locals {
  ssh_timeout = 240
}

resource "toolbox_external" "setup_volumes" {
  count = local.additional_volumes_count
  query = {
    depend0 = can(toolbox_external.all_block_devices)
    depends1 = local.additional_volumes_length
  }
  program = [
    "bash",
    "-c",
    <<-EOT
    CONNECTION="${var.operating_system.ssh_user}@${azurerm_linux_virtual_machine.main.public_ip_address}"
    SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=${local.ssh_timeout}"
    SFTP_OPTIONS="-P ${var.machine.ssh_port} -i ${var.operating_system.ssh_private_key_file} $SSH_OPTIONS"

    # Copy script to /tmp directory
    CMD="sftp -b <(printf '%s\n' 'put ${abspath(path.module)}/setup_volume.sh') $SFTP_OPTIONS $CONNECTION:/tmp/"
    RESULT=$(eval $CMD)
    RC=$?
    if [[ $RC -ne 0 ]];
    then
      printf "%s\n" "$RESULT" 1>&2
      exit $RC
    fi

    ADDITIONAL_SSH_OPTIONS="-p ${var.machine.ssh_port} -i ${var.operating_system.ssh_private_key_file}"
    SSH_CMD="ssh $CONNECTION $ADDITIONAL_SSH_OPTIONS $SSH_OPTIONS"

    # Set script as executable
    CMD="$SSH_CMD chmod a+x /tmp/setup_volume.sh 2>&1"
    RESULT=$($CMD)
    RC=$?
    if [[ $RC -ne 0 ]];
    then
      printf "%s\n" "$RESULT" 1>&2
      exit $RC
    fi

    # Execute Script
    CMD="$SSH_CMD /tmp/setup_volume.sh ${base64encode(jsonencode(local.script_variables))} >> /tmp/mount.log 2>&1"
    RESULT=$($CMD)
    RC=$?
    if [[ $RC -ne 0 ]];
    then
      printf "%s\n" "$RESULT" 1>&2
      exit $RC
    fi

    jq -n --arg base64json "$(printf %s $result | base64 | tr -d \\n)" '{"base64json": $base64json}'
    EOT
  ]
}

resource "toolbox_external" "final_block_devices" {
  count = local.additional_volumes_count
  query = {
    depend0 = can(toolbox_external.setup_volumes)
    depends1 = local.additional_volumes_length
  }
  program = [
    "bash",
    "-c",
    "${abspath(path.module)}/lsblk_devices.sh '${var.operating_system.ssh_user}@${azurerm_linux_virtual_machine.main.public_ip_address} -p ${var.machine.ssh_port} -i ${var.operating_system.ssh_private_key_file}'",
  ]
}

locals {
  final_block_devices = can(toolbox_external.final_block_devices.0.result) ? jsondecode(base64decode(toolbox_external.final_block_devices.0.result.base64json)) : {}
}
