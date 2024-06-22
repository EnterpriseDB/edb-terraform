# Create default keys when ssh_user is supplied.
# If ssh_key.public_path and ssh_key.private_path are defined,
# overwrite the default keys.
locals {
  ssh_user_count = local.spec.images != null ? 1 : 0
  ssh_keys_count = (
    local.spec.ssh_key.public_path != null ||
    local.spec.ssh_key.private_path != null ? 1 : 0
  )
  private_ssh_path = "${abspath(path.root)}/${local.spec.ssh_key.output_name}"
  public_ssh_path = "${abspath(path.root)}/${local.spec.ssh_key.output_name}.pub"
}

resource "tls_private_key" "default" {
  count     = local.ssh_user_count
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "default_private" {
  count = local.ssh_user_count

  filename        = local.private_ssh_path
  file_permission = "0600"
  content         = try(tls_private_key.default[0].private_key_openssh, "")
}

resource "local_file" "default_public" {
  count = local.ssh_user_count

  filename        = local.public_ssh_path
  file_permission = "0644"
  content         = try(tls_private_key.default[0].public_key_openssh, "")
}

resource "local_sensitive_file" "private_key" {
  count = local.ssh_keys_count

  filename        = local.private_ssh_path
  file_permission = "0600"
  source          = local.spec.ssh_key.private_path

  lifecycle {
    precondition {
      condition     = local.spec.ssh_key.public_path != local.spec.ssh_key.private_path
      error_message = "private_path and private_path cannot be the same"
    }
    precondition {
      condition     = fileexists(local.spec.ssh_key.private_path)
      error_message = "Unable to find or access the private key"
    }
    precondition {
      condition     = local.spec.ssh_key.public_path != null
      error_message = "public_path must be defined when using private_path"
    }
  }

  depends_on = [local_sensitive_file.private_key]
}

resource "local_file" "public_key" {
  count = local.ssh_keys_count

  filename        = local.public_ssh_path
  file_permission = "0644"
  source          = local.spec.ssh_key.public_path

  lifecycle {
    precondition {
      condition     = fileexists(local.spec.ssh_key.public_path)
      error_message = "Unable to access the public key"
    }
    precondition {
      condition     = local.spec.ssh_key.private_path != null
      error_message = "private_path must be defined when using public_path"
    }
  }

  depends_on = [local_file.public_key]
}
