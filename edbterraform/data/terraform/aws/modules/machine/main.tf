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

resource "aws_instance" "machine" {
  ami                    = data.aws_ami.default.id
  instance_type          = var.machine.spec.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.custom_security_group_ids

  root_block_device {
    delete_on_termination = "true"
    volume_size           = var.machine.spec.volume.size_gb
    volume_type           = var.machine.spec.volume.type
    iops                  = var.machine.spec.volume.type == "io2" ? var.machine.spec.volume.iops : var.machine.spec.volume.type == "io1" ? var.machine.spec.volume.iops : null
  }

  tags = var.tags

  lifecycle {
    # AMI is ignored because the data source
    # forces the resource to be re-created when apply is used again
    ignore_changes = [ami]
  }
}

resource "aws_ebs_volume" "ebs_volume" {
  for_each = { for i, v in lookup(var.machine.spec, "additional_volumes", []) : i => v }

  availability_zone = var.az
  size              = each.value.size_gb
  type              = each.value.type
  iops              = each.value.type == "io2" ? each.value.iops : each.value.type == "io1" ? each.value.iops : null
  encrypted         = each.value.encrypted

  tags = var.tags
}

resource "aws_volume_attachment" "attached_volume" {
  for_each = { for i, v in lookup(var.machine.spec, "additional_volumes", []) : i => v }

  device_name = element(local.linux_device_names, tonumber(each.key))[0]
  volume_id   = aws_ebs_volume.ebs_volume[each.key].id
  instance_id = aws_instance.machine.id
  stop_instance_before_detaching = true

  depends_on = [
    aws_instance.machine,
    aws_ebs_volume.ebs_volume
  ]
}

resource "null_resource" "copy_setup_volume_script" {

  count = length(lookup(var.machine.spec, "additional_volumes", [])) > 0 ? 1 : 0

  provisioner "file" {
    content     = file("${abspath(path.module)}/setup_volume.sh")
    destination = "/tmp/setup_volume.sh"

    connection {
      type        = "ssh"
      user        = var.operating_system.ssh_user
      host        = aws_instance.machine.public_ip
      agent       = var.use_agent # agent and private_key conflict
      private_key = var.use_agent ? null : var.ssh_priv_key
    }
  }

  depends_on = [
    aws_volume_attachment.attached_volume
  ]
}

resource "null_resource" "setup_volume" {
  for_each = { for i, v in lookup(var.machine.spec, "additional_volumes", []) : i => v }

  depends_on = [
    null_resource.copy_setup_volume_script
  ]

  provisioner "remote-exec" {
    inline = [
      "chmod a+x /tmp/setup_volume.sh",
      "/tmp/setup_volume.sh ${element(local.string_device_names, tonumber(each.key))} ${each.value.mount_point} ${length(lookup(var.machine.spec, "additional_volumes", [])) + 1}  >> /tmp/mount.log 2>&1"
    ]

    connection {
      type        = "ssh"
      user        = var.operating_system.ssh_user
      host        = aws_instance.machine.public_ip
      agent       = var.use_agent # agent and private_key conflict
      private_key = var.use_agent ? null : var.ssh_priv_key
    }
  }
}
