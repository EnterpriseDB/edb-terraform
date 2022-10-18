variable "machine" {}
variable "vpc_id" {}
variable "cidr_block" {}
variable "az" {}
variable "ssh_user" {}
variable "ssh_pub_key" {}
variable "ssh_priv_key" {}
variable "custom_security_group_id" {}
variable "cluster_name" {}
variable "created_by" {}
variable "key_name" {}
variable "operating_system" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
  }
}
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


data "aws_subnet" "selected" {
  vpc_id            = var.vpc_id
  availability_zone = var.az
  cidr_block        = var.cidr_block
}

resource "aws_instance" "machine" {
  ami                    = data.aws_ami.default.id
  instance_type          = var.machine.spec.instance_type
  key_name               = var.key_name
  subnet_id              = data.aws_subnet.selected.id
  vpc_security_group_ids = [var.custom_security_group_id]

  root_block_device {
    delete_on_termination = "true"
    volume_size           = var.machine.spec.volume.size_gb
    volume_type           = var.machine.spec.volume.type
    iops                  = var.machine.spec.volume.type == "io2" ? var.machine.spec.volume.iops : var.machine.spec.volume.type == "io1" ? var.machine.spec.volume.iops : null
  }

  tags = {
    Name       = format("%s-%s", var.cluster_name, var.machine.name)
    Created_By = var.created_by
  }

  connection {
    private_key = file(var.ssh_pub_key)
  }
}

resource "aws_ebs_volume" "ebs_volume" {
  for_each = { for i, v in lookup(var.machine.spec, "additional_volumes", []) : i => v }

  availability_zone = var.az
  size              = each.value.size_gb
  type              = each.value.type
  iops              = each.value.type == "io2" ? each.value.iops : each.value.type == "io1" ? each.value.iops : null
  encrypted         = each.value.encrypted

  tags = {
    Name = format("%s-%s-%s-%s", var.machine.name, var.cluster_name, "ebs", each.key)
  }
}

locals {
  linux_ebs_device_names = [
    "/dev/sdf",
    "/dev/sdg",
    "/dev/sdh",
    "/dev/sdi",
    "/dev/sdj",
    "/dev/sdk",
    "/dev/sdl"
  ]
}

resource "aws_volume_attachment" "attached_volume" {
  for_each = { for i, v in lookup(var.machine.spec, "additional_volumes", []) : i => v }

  device_name = element(local.linux_ebs_device_names, tonumber(each.key))
  volume_id   = aws_ebs_volume.ebs_volume[each.key].id
  instance_id = aws_instance.machine.id

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
      user        = var.ssh_user
      host        = aws_instance.machine.public_ip
      private_key = file(var.ssh_priv_key)
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
      "/tmp/setup_volume.sh ${element(local.linux_ebs_device_names, tonumber(each.key))} ${each.value.mount_point} ${length(lookup(var.machine.spec, "additional_volumes", [])) + 1}  >> /tmp/mount.log 2>&1"
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      host        = aws_instance.machine.public_ip
      private_key = file(var.ssh_priv_key)
    }
  }
}
