module "machine_ports" {
  source = "../security"

  vpc_id           = var.vpc_id
  cluster_name     = var.machine.name
  ports            = var.machine.spec.ports
  tags             = var.tags
  public_cidrblocks = var.public_cidrblocks
  service_cidrblocks = var.service_cidrblocks
  internal_cidrblocks = var.internal_cidrblocks
}

# TODO: Allow machine configurations to accept a list of instance types and create a single instance from that list
# - AWS allows this through launch templates and setting a scaling group to size 1 but requires manual checking for instance creation
#   - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group
# - GCP allows this through machine templates, setting a scaling group to size 1 and waiting for initial instances to be created
#   - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager
#   - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_autoscaler
# - Azure doesn't seem to allow multiple skus to be set for scaling group
#   - easiest path would be breaking out of terraform and manually attempting to create instances until first success
#     - we can ignore updates and blindly re-create since it is assumed instances are created once and any updates should be outside of terraform or re-create the entire resource
resource "aws_instance" "machine" {
  ami                    = var.image_info[var.machine.spec.image_name].id
  instance_type          = var.machine.spec.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = flatten([local.security_group_ids, module.machine_ports.security_group_ids])

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

  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html
  user_data_base64 = var.machine.spec.user_data == null ? var.machine.spec.user_data : base64encode(var.machine.spec.user_data)
  # user_data_replace_on_change = false # default
  # user_data = null # default

  tags = var.tags

  lifecycle {
    ignore_changes = [
      # Tags appear as null during re-applys
      tags["Owner"],
      root_block_device[0].tags["Owner"],
      root_block_device[0].tags["AttachedInstance"],
      # Block devices are attached after this resource but fail to be ignored
      # Using terraform apply a second time will track the devices within this resource and will no longer appear as a diff.
      # No workaround available at this time.
      # https://github.com/hashicorp/terraform-provider-aws/issues/33850
      # ebs_block_device,
    ]
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
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
  count = local.additional_volumes_length > 0 || local.execute_preattached_volumes ? 1 : 0
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
  count = local.additional_volumes_length > 0 || local.execute_preattached_volumes ? 1 : 0
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
  ssh_timeout = 240

  preattached_volumes_script = "setup_preattached_volumes.sh"
  preattached_volumes_variables = {
    "required": coalesce(try(var.machine.spec.preattached_volumes.required, null), false)
    "volume_group": coalesce(try(var.machine.spec.preattached_volumes.volume_group, null), "preattached_storage")
    "mount_points": {
      for mount_point, attributes in coalesce(try(var.machine.spec.preattached_volumes.mount_points, null), {}): mount_point => {
        "size": coalesce(attributes.size, "100%FREE")
        "filesystem": coalesce(attributes.filesystem, local.filesystem)
        "mount_options": try(join(",", attributes.mount_options), join(",", local.mount_options))
        "type": "striped"
        "stripesize": "64 KB"
    }}
  }

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

resource "toolbox_external" "setup_preattached_volumes" {
  count = local.execute_preattached_volumes ? 1 : 0
  query = {
    depend0 = can(toolbox_external.all_block_devices)
  }
  program = [
    "bash",
    "-c",
    <<-EOT
    ERROR_CHECK() {
      if [[ $1 -ne 0 ]];
      then
        printf "%s\n" "$2" 1>&2
        exit $1
      fi
    }

    CONNECTION="${var.operating_system.ssh_user}@${aws_instance.machine.public_ip}"
    SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=${local.ssh_timeout}"
    SFTP_OPTIONS="-P ${var.machine.spec.ssh_port} -i ${var.machine.spec.operating_system.ssh_private_key_file} $SSH_OPTIONS"

    # Copy script to /tmp directory
    CMD="sftp -b <(printf '%s\n' 'put ${abspath(path.module)}/${local.preattached_volumes_script}') $SFTP_OPTIONS $CONNECTION:/tmp/"
    RESULT=$(eval $CMD)
    ERROR_CHECK $? $RESULT

    ADDITIONAL_SSH_OPTIONS="-p ${var.machine.spec.ssh_port} -i ${var.machine.spec.operating_system.ssh_private_key_file}"
    SSH_CMD="ssh $CONNECTION $ADDITIONAL_SSH_OPTIONS $SSH_OPTIONS"

    # Set script as executable
    CMD="$SSH_CMD chmod a+x /tmp/${local.preattached_volumes_script}"
    RESULT=$($CMD)
    ERROR_CHECK $? $RESULT

    # Execute Script
    CMD="$SSH_CMD /tmp/${local.preattached_volumes_script} ${base64encode(jsonencode(local.preattached_volumes_variables))} ${toolbox_external.initial_block_devices.0.result.base64json} >> /tmp/mount.log"
    RESULT=$($CMD)
    ERROR_CHECK $? $RESULT

    jq -n --arg base64json "$(printf %s $RESULT | base64 | tr -d \\n)" '{"base64json": $base64json}'
    EOT
  ]
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
    SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=${local.ssh_timeout}"
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

    jq -n --arg base64json "$(printf %s $RESULT | base64 | tr -d \\n)" '{"base64json": $base64json}'
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
