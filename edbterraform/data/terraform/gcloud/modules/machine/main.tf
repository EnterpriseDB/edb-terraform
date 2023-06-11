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

module "machine_ports" {
  source = "../security"

  network_name     = var.network_name
  ports            = var.machine.spec.ports
  ingress_cidrs    = flatten([google_compute_instance.machine.network_interface.*.network_ip, google_compute_instance.machine.network_interface[*].access_config.*.nat_ip])
  egress_cidrs     = flatten([google_compute_instance.machine.network_interface.*.network_ip, google_compute_instance.machine.network_interface[*].access_config.*.nat_ip])
  region           = var.machine.spec.region
  name_id          = "${var.machine.name}-${var.name_id}"
}

resource "null_resource" "ensure_ssh_open" {
  count = local.additional_volumes_count
  triggers = {
    "depends_on" = local.additional_volumes_length
  }

  provisioner "remote-exec" {
    inline = [
      "echo connected",
    ]
    connection {
      type        = "ssh"
      user        = var.operating_system.ssh_user
      host        = google_compute_instance.machine.network_interface.0.access_config.0.nat_ip
      port        = var.machine.spec.ssh_port
      agent       = var.use_agent # agent and private_key conflict
      private_key = var.use_agent ? null : var.ssh_priv_key
    }
  }
}

resource "google_compute_disk" "volumes" {
  for_each = local.additional_volumes_map

  name             = lower(format("%s-%s-%s-%s", var.machine.name, var.cluster_name, var.name_id, each.key))
  type             = each.value.type
  size             = each.value.size_gb
  zone             = var.machine.spec.zone
  provisioned_iops = try(each.value.iops, null)
  # Implicit dependency to aws_ebs_volume.ebs_volume
  labels = can(null_resource.ensure_ssh_open) ? var.tags : var.tags

}

resource "google_compute_attached_disk" "attached_volumes" {
  for_each = local.additional_volumes_map

  device_name = trimprefix(element(local.linux_device_names, tonumber(each.key))[0], local.prefix)
  disk        = google_compute_disk.volumes[each.key].id
  instance    = can(google_compute_disk.volumes) ? google_compute_instance.machine.id : google_compute_instance.machine.id

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
      type        = can(google_compute_attached_disk.attached_volumes) ? "ssh" : "ssh"
      user        = var.operating_system.ssh_user
      host        = google_compute_instance.machine.network_interface.0.access_config.0.nat_ip
      port        = var.machine.spec.ssh_port
      agent       = var.use_agent # agent and private_key conflict
      private_key = var.use_agent ? null : var.ssh_priv_key
    }
  }
}

resource "null_resource" "setup_volume" {
  for_each = local.additional_volumes_map
  provisioner "remote-exec" {
    inline = [
      "chmod a+x /tmp/setup_volume.sh",
      "/tmp/setup_volume.sh ${element(local.string_device_names, tonumber(each.key))} ${each.value.mount_point} ${length(lookup(var.machine.spec, "additional_volumes", [])) + 1}  >> /tmp/mount.log 2>&1"
    ]
    connection {
      # Implicit dependency to null_resource.copy_setup_volume_script
      type        = can(null_resource.copy_setup_volume_script) ? "ssh" : "ssh"
      user        = var.operating_system.ssh_user
      host        = google_compute_instance.machine.network_interface.0.access_config.0.nat_ip
      port        = var.machine.spec.ssh_port
      agent       = var.use_agent # agent and private_key conflict
      private_key = var.use_agent ? null : var.ssh_priv_key
    }
  }
}
