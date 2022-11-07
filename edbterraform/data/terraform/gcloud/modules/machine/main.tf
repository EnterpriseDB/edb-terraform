variable "machine" {}
variable "cidr_block" {}
variable "az" {}
variable "ssh_user" {}
variable "ssh_pub_key" {}
variable "ssh_priv_key" {}
variable "ssh_metadata" {}
variable "cluster_name" {}
variable "operating_system" {}
variable "subnet_name" {}
variable "name_id" { default = "0" }
variable "public_subnet_tag" {}

data "google_compute_zones" "available" {
  region = var.machine.spec.region
}

data "google_compute_subnetwork" "selected" {
  region = data.google_compute_zones.available.id
  name = var.subnet_name
}

data "google_compute_image" "image" {
  name = var.operating_system.name
}

resource "google_compute_address" "public_ip" {
  name   = format("public-ip-%s-%s", var.machine.name, var.name_id)
  region = var.machine.spec.region
  address_type = "EXTERNAL"
}

resource "google_compute_instance" "machine" {
  name         = format("%s-%s-%s", var.cluster_name, var.machine.name, var.name_id)
  machine_type = var.machine.spec.instance_type
  zone = var.az

  boot_disk {
    initialize_params {
      image = data.google_compute_image.image.self_link
      type  = var.machine.spec.volume.type
      size  = var.machine.spec.volume.size_gb
    }
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.selected.name
    access_config {
      nat_ip = google_compute_address.public_ip.address
    }
  }

  lifecycle {
    ignore_changes = [attached_disk]
  }

  metadata = { ssh-keys = var.ssh_metadata }
}

resource "google_compute_disk" "volumes" {
  for_each = { for i, v in lookup(var.machine.spec, "additional_volumes", []) : i => v }

  #name  = format("%s-%s-%s-%s", var.cluster_name, var.machine.name, try(index(var.machine.spec.additional_volumes, each.value), 0) ,var.name_id)
  name = format("%s-%s-%s-%s", var.machine.name, var.cluster_name, var.name_id, each.key)
  type  = each.value.type
  size  = each.value.size_gb
  zone  = var.machine.spec.az
  provisioned_iops = try(each.value.iops, null)

  depends_on = [google_compute_instance.machine]
}

locals {
  linux_device_names = [
    "sdf",
    "sdg",
    "sdh",
    "sdi",
    "sdj",
    "sdk",
    "sdl"
  ]
}

resource "google_compute_attached_disk" "attached_volumes" {
  # for_each = google_compute_disk.volumes
  for_each = { for i, v in lookup(var.machine.spec, "additional_volumes", []) : i => v }

  device_name = element(local.linux_device_names, tonumber(each.key))
  #disk     = each.value.id
  disk = google_compute_disk.volumes[each.key].id
  instance = google_compute_instance.machine.id

  depends_on = [google_compute_disk.volumes]
}

resource "null_resource" "copy_setup_volume_script" {

  count = length(lookup(var.machine.spec, "additional_volumes", [])) > 0 ? 1 : 0

  provisioner "file" {
    content     = file("${abspath(path.module)}/setup_volume.sh")
    destination = "/tmp/setup_volume.sh"

    # Requires firewall access to ssh port
    connection {
      type        = "ssh"
      user        = var.ssh_user
      host        = google_compute_instance.machine.network_interface.0.access_config.0.nat_ip
      private_key = file(var.ssh_priv_key)
    }
  }

  depends_on = [
    google_compute_attached_disk.attached_volumes
  ]

}

resource "null_resource" "setup_volume" {
  for_each = { for i, v in lookup(var.machine.spec, "additional_volumes", []) : i => v }

  provisioner "remote-exec" {
    inline = [
      "chmod a+x /tmp/setup_volume.sh",
      "/tmp/setup_volume.sh \"/dev/disk/by-id/google-${element(local.linux_device_names, tonumber(each.key))}\" ${each.value.mount_point} ${length(lookup(var.machine.spec, "additional_volumes", [])) + 1}  >> /tmp/mount.log 2>&1"
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      host        = google_compute_instance.machine.network_interface.0.access_config.0.nat_ip
      private_key = file(var.ssh_priv_key)
    }
  }

  depends_on = [
    null_resource.copy_setup_volume_script
  ]
}
