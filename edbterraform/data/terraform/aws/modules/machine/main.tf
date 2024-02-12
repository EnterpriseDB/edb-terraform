data "aws_ami" "default" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.operating_system.name}*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["${var.operating_system.owner}"]
}

module "machine_ports" {
  source = "../security"

  vpc_id           = var.vpc_id
  cluster_name     = var.machine.name
  ports            = local.machine_ports
  tags             = var.tags
}

resource "aws_instance" "machine" {
  ami                    = data.aws_ami.default.id
  instance_type          = var.machine.spec.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = flatten([var.custom_security_group_ids, module.machine_ports.security_group_ids])

  dynamic "instance_market_options" {
    for_each = var.machine.spec.spot == true ? [1] : []
    content {
      market_type = "spot"
      dynamic "spot_options" {
        for_each = var.machine.spec.spot == true ? [1] : []
        content {
          instance_interruption_behavior = "stop"
          spot_instance_type = "persistent"
        }
      }
    }
  }

  root_block_device {
    delete_on_termination = "true"
    volume_size           = var.machine.spec.volume.size_gb
    volume_type           = var.machine.spec.volume.type
    iops                  = var.machine.spec.volume.type == "io2" ? var.machine.spec.volume.iops : var.machine.spec.volume.type == "io1" ? var.machine.spec.volume.iops : null
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      # AMI is ignored because the data source forces the resource to be re-created when apply is used again
      ami,
      # Tags appear as null during re-applys
      tags["Owner"],
      root_block_device[0].tags["Owner"],
      root_block_device[0].tags["AttachedInstance"],
    ]
  }
}

# Create set of volumes around the machine instance to be attached post-terraform
resource "aws_ebs_volume" "jbod_volumes" {
  for_each = var.machine.spec.jbod_volumes != null && var.machine.spec.jbod_volumes != {} ? var.machine.spec.jbod_volumes : {}

  availability_zone = var.az
  size              = each.value.size_gb
  type              = each.value.type
  # IOPs and throughput limited to certain volume types
  iops              = contains(["io1","io2","gp3"], each.value.type) ? each.value.iops : null
  throughput        = contains(["gp3"], each.value.type) ? each.value.throughput : null
  encrypted         = each.value.encrypted

  tags = var.tags
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
      host        = aws_instance.machine.public_ip
      port        = var.machine.spec.ssh_port
      agent       = var.use_agent # agent and private_key conflict
      private_key = var.use_agent ? null : var.ssh_priv_key
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
    "${abspath(path.module)}/lsblk_devices.sh '${var.operating_system.ssh_user}@${aws_instance.machine.public_ip} -p ${var.machine.spec.ssh_port} -i ${var.machine.spec.operating_system.ssh_private_key_file}'",
  ]
}

locals {
  initial_block_devices = can(toolbox_external.initial_block_devices.0.result) ? jsondecode(base64decode(toolbox_external.initial_block_devices.0.result.base64json)) : {}
}

resource "aws_ebs_volume" "ebs_volume" {
  for_each = local.additional_volumes_map 

  availability_zone = var.az
  size              = each.value.size_gb
  type              = each.value.type
  # IOPs and throughput limited to certain volume types
  iops              = contains(["io1","io2","gp3"], each.value.type) ? each.value.iops : null
  throughput        = contains(["gp3"], each.value.type) ? each.value.throughput : null
  encrypted         = each.value.encrypted

  # Implicit dependency to initial devices check
  tags = can(toolbox_external.initial_block_devices) ? var.tags : var.tags
}

resource "aws_volume_attachment" "attached_volume" {
  for_each = local.additional_volumes_map

  device_name = element(local.linux_device_names, tonumber(each.key))[0]
  volume_id   = aws_ebs_volume.ebs_volume[each.key].id
  instance_id = aws_instance.machine.id
  # Implicit dependency to aws_ebs_volume.ebs_volume
  stop_instance_before_detaching = can(aws_ebs_volume.ebs_volume) ? true : true
  lifecycle {
    ignore_changes = [volume_id]
  }
}

resource "toolbox_external" "all_block_devices" {
  count = local.additional_volumes_count
  query = {
    depend0 = can(aws_volume_attachment.attached_volume)
    depends1 = local.additional_volumes_length
  }
  program = [
    "bash",
    "-c",
    "${abspath(path.module)}/lsblk_devices.sh '${var.operating_system.ssh_user}@${aws_instance.machine.public_ip} -p ${var.machine.spec.ssh_port} -i ${var.machine.spec.operating_system.ssh_private_key_file}'",
  ]
}

locals {
  all_block_devices = can(toolbox_external.all_block_devices.0.result) ? jsondecode(base64decode(toolbox_external.all_block_devices.0.result.base64json)) : {}
}

locals {
  volume_variables = [
    for key, values in local.additional_volumes_map: {
        "device_names": element(local.linux_device_names, tonumber(key))
        "number_of_volumes": length(lookup(var.machine.spec, "additional_volumes", [])) + 1
        "mount_point": values.mount_point
        "mount_options": coalesce(try(join(",", values.mount_options), null), try(join(",", local.mount_options), null))
        "filesystem": coalesce(values.filesystem, local.filesystem)
        "volume_group": values.volume_group
    }
  ]
  lvm_variables = {
    for volume_group, values in var.machine.spec.volume_groups : volume_group => {
        for mount_point, attibutes in values: mount_point => {
          "size": coalesce(attibutes.size, "100%FREE")
          "filesystem": coalesce(attibutes.filesystem, local.filesystem)
          "mount_options": coalesce(try(join(",", attibutes.mount_options), null), try(join(",", local.mount_options), null))
          "type": "striped"
          "stripesize": "64 KB"
      }
    }
  }
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
    CONNECTION="${var.operating_system.ssh_user}@${aws_instance.machine.public_ip}"
    SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    SFTP_OPTIONS="-P ${var.machine.spec.ssh_port} -i ${var.machine.spec.operating_system.ssh_private_key_file} $SSH_OPTIONS"

    # Copy script to /tmp directory
    CMD="sftp -b <(printf '%s\n' 'put ${abspath(path.module)}/setup_volume.sh') $SFTP_OPTIONS $CONNECTION:/tmp/"
    RESULT=$(eval $CMD)
    RC=$?
    if [[ $RC -ne 0 ]];
    then
      printf "%s\n" "$RESULT" 1>&2
      exit $RC
    fi

    ADDITIONAL_SSH_OPTIONS="-p ${var.machine.spec.ssh_port} -i ${var.machine.spec.operating_system.ssh_private_key_file}"
    SSH_CMD="ssh $CONNECTION $ADDITIONAL_SSH_OPTIONS $SSH_OPTIONS"

    # Set script as executable
    CMD="$SSH_CMD chmod a+x /tmp/setup_volume.sh"
    RESULT=$($CMD)
    RC=$?
    if [[ $RC -ne 0 ]];
    then
      printf "%s\n" "$RESULT" 1>&2
      exit $RC
    fi

    # Execute Script
    CMD="$SSH_CMD /tmp/setup_volume.sh ${base64encode(jsonencode(local.volume_variables))} ${base64encode(jsonencode(local.lvm_variables))} >> /tmp/mount.log"
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
    "${abspath(path.module)}/lsblk_devices.sh '${var.operating_system.ssh_user}@${aws_instance.machine.public_ip} -p ${var.machine.spec.ssh_port} -i ${var.machine.spec.operating_system.ssh_private_key_file}'",
  ]
}

locals {
  final_block_devices = can(toolbox_external.final_block_devices.0.result) ? jsondecode(base64decode(toolbox_external.final_block_devices.0.result.base64json)) : {}
}
