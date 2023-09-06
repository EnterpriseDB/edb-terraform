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
  name         = local.public_ip_name
  region       = var.machine.spec.region
  address_type = "EXTERNAL"
  # TODO: Add labels once they are out of beta. 2023-05-05
}

resource "google_compute_instance" "machine" {
  name           = local.machine_name
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
    "depends_on" = can(module.machine_ports) ? local.additional_volumes_length : local.additional_volumes_length
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

resource "toolbox_external" "initial_block_devices" {
  count = local.additional_volumes_count
  query = {
    depend0 = can(null_resource.ensure_ssh_open)
    depends1 = local.additional_volumes_length
  }
  program = [
    "bash",
    "-c",
    "${abspath(path.module)}/lsblk_devices.sh '${var.operating_system.ssh_user}@${google_compute_instance.machine.network_interface.0.access_config.0.nat_ip} -p ${var.machine.spec.ssh_port} -i ${var.operating_system.ssh_private_key_file}'",
  ]
}

locals {
  initial_block_devices = can(toolbox_external.initial_block_devices.0.result) ? jsondecode(base64decode(toolbox_external.initial_block_devices.0.result.base64json)) : {}
}

resource "google_compute_disk" "volumes" {
  for_each = local.additional_volumes_map

  name             = lower(format("%s-%s-%s-%s", var.machine.name, var.cluster_name, var.name_id, each.key))
  type             = each.value.type
  size             = each.value.size_gb
  zone             = var.machine.spec.zone
  provisioned_iops = try(each.value.iops, null)
  # Implicit dependency to previous step
  labels = can(toolbox_external.initial_block_devices) ? local.labels : local.labels

}

resource "google_compute_attached_disk" "attached_volumes" {
  for_each = local.additional_volumes_map

  device_name = trimprefix(element(local.linux_device_names, tonumber(each.key))[0], local.prefix)
  disk        = google_compute_disk.volumes[each.key].id
  instance    = can(google_compute_disk.volumes) ? google_compute_instance.machine.id : google_compute_instance.machine.id

}

resource "toolbox_external" "all_block_devices" {
  count = local.additional_volumes_count
  query = {
    depend0 = can(google_compute_attached_disk.attached_volumes)
    depends1 = local.additional_volumes_length
  }
  program = [
    "bash",
    "-c",
    "${abspath(path.module)}/lsblk_devices.sh '${var.operating_system.ssh_user}@${google_compute_instance.machine.network_interface.0.access_config.0.nat_ip} -p ${var.machine.spec.ssh_port} -i ${var.operating_system.ssh_private_key_file}'",
  ]
}

locals {
  all_block_devices = can(toolbox_external.all_block_devices.0.result) ? jsondecode(base64decode(toolbox_external.all_block_devices.0.result.base64json)) : {}
}

locals {
  script_variables = [
    for key, values in local.additional_volumes_map: {
        "device_names": element(local.linux_device_names, tonumber(key))
        "number_of_volumes": length(lookup(var.machine.spec, "additional_volumes", [])) + 1
        "mount_point": values.mount_point
        "mount_options": coalesce(try(join(",", values.mount_options), null), try(join(",", local.mount_options), null))
        "filesystem": coalesce(values.filesystem, local.filesystem)
    }
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
    CONNECTION="${var.operating_system.ssh_user}@${google_compute_instance.machine.network_interface.0.access_config.0.nat_ip}"
    SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    SFTP_OPTIONS="-P ${var.machine.spec.ssh_port} -i ${var.operating_system.ssh_private_key_file} $SSH_OPTIONS"

    # Copy script to /tmp directory
    CMD="sftp -b <(printf '%s\n' 'put ${abspath(path.module)}/setup_volume.sh') $SFTP_OPTIONS $CONNECTION:/tmp/"
    RESULT=$(eval $CMD)
    RC=$?
    if [[ $RC -ne 0 ]];
    then
      printf "%s\n" "$RESULT" 1>&2
      exit $RC
    fi

    ADDITIONAL_SSH_OPTIONS="-p ${var.machine.spec.ssh_port} -i ${var.operating_system.ssh_private_key_file}"
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
    "${abspath(path.module)}/lsblk_devices.sh '${var.operating_system.ssh_user}@${google_compute_instance.machine.network_interface.0.access_config.0.nat_ip} -p ${var.machine.spec.ssh_port} -i ${var.operating_system.ssh_private_key_file}'",
  ]
}

locals {
  final_block_devices = can(toolbox_external.final_block_devices.0.result) ? jsondecode(base64decode(toolbox_external.final_block_devices.0.result.base64json)) : {}
}
