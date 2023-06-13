data "google_compute_zones" "available" {
  region = var.machine.spec.region
}

data "google_compute_subnetwork" "selected" {
  region = data.google_compute_zones.available.id
  name   = var.subnet_name
}

data "google_compute_image" "image" {
  name = var.operating_system.name
  family = var.operating_system.family
  project = var.operating_system.project
}

resource "google_compute_address" "public_ip" {
  name         = format("public-ip-%s-%s", var.machine.name, var.name_id)
  region       = var.machine.spec.region
  address_type = "EXTERNAL"
  # TODO: Add labels once they are out of beta. 2023-05-05
}

resource "google_compute_instance" "machine" {
  # name expects to be lower case
  name           = lower(format("%s-%s-%s", var.cluster_name, var.machine.name, var.name_id))
  machine_type   = var.machine.spec.instance_type
  zone           = var.zone
  can_ip_forward = try(var.machine.spec.ip_forward, var.ip_forward)
  allow_stopping_for_update = true

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
    ignore_changes = [
      # VM recreated on re-apply if not ignored
      boot_disk,
      # Disks de-tach on re-apply if not ignored
      attached_disk,
    ]
  }

  metadata = { ssh-keys = "${var.operating_system.ssh_user}:${var.ssh_pub_key}" }
  labels   = local.labels
}

resource "google_compute_disk" "volumes" {
  for_each = { for i, v in lookup(var.machine.spec, "additional_volumes", []) : i => v }

  name             = lower(format("%s-%s-%s-%s", var.machine.name, var.cluster_name, var.name_id, each.key))
  type             = each.value.type
  size             = each.value.size_gb
  zone             = var.machine.spec.zone
  provisioned_iops = try(each.value.iops, null)
  labels           = local.labels

  depends_on = [google_compute_instance.machine]

}

resource "google_compute_attached_disk" "attached_volumes" {
  for_each = { for i, v in lookup(var.machine.spec, "additional_volumes", []) : i => v }

  device_name = trimprefix(element(local.linux_device_names, tonumber(each.key))[0], local.prefix)
  disk        = google_compute_disk.volumes[each.key].id
  instance    = google_compute_instance.machine.id

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
      user        = var.operating_system.ssh_user
      host        = google_compute_instance.machine.network_interface.0.access_config.0.nat_ip
      agent       = var.use_agent # agent and private_key conflict
      private_key = var.use_agent ? null : var.ssh_priv_key
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
      "/tmp/setup_volume.sh ${element(local.string_device_names, tonumber(each.key))} ${each.value.mount_point} ${length(lookup(var.machine.spec, "additional_volumes", [])) + 1}  >> /tmp/mount.log 2>&1"
    ]

    # Requires firewall access to ssh port
    connection {
      type        = "ssh"
      user        = var.operating_system.ssh_user
      host        = google_compute_instance.machine.network_interface.0.access_config.0.nat_ip
      agent       = var.use_agent # agent and private_key conflict
      private_key = var.use_agent ? null : var.ssh_priv_key
    }
  }

  depends_on = [
    null_resource.copy_setup_volume_script
  ]
}
