variable "tags" {
  description = "Project Level Tags to be merged with other tags"
  type        = map(string)
  default = {
    cluster_name = "GCloud-Cluster-default"
    created_by   = "EDB-Terraform-GCloud"
  }
  nullable = true
}

variable "ssh_key" {
  type = object({
    public_path  = optional(string)
    private_path = optional(string)
    output_name  = optional(string, "ssh-id_rsa")
    use_agent    = optional(bool, false)
  })
  default  = {}
  nullable = true
}

variable "images" {
  description = ""
  type = map(object({
    name     = optional(string)
    family   = optional(string)
    project  = optional(string)
    ssh_user = optional(string)
  }))
  default  = {}
  nullable = true
}

variable "regions" {
  type = map(object({
    cidr_block = string
    zones = optional(map(object({
      zone = optional(string)
      cidr = optional(string)
    })), {})
    ports = optional(list(object({
      defaults    = optional(string, "")
      port        = optional(number)
      to_port     = optional(number)
      protocol    = string
      description = optional(string, "default")
      type        = optional(string, "ingress")
      access      = optional(string, "allow")
      cidrs       = optional(list(string), [])
    })), [])
  }))
}

variable "machines" {
  type = map(object({
    type          = optional(string)
    image_name    = string
    count         = optional(number, 1)
    region        = string
    zone_name     = string
    instance_type = string
    ip_forward    = optional(bool)
    ssh_port      = optional(number, 22)
    ports = optional(list(object({
      defaults    = optional(string, "")
      port        = optional(number)
      to_port     = optional(number)
      protocol    = string
      description = optional(string, "default")
      type        = optional(string, "ingress")
      access      = optional(string, "allow")
      cidrs       = optional(list(string), [])
    })), [])
    volume = object({
      type      = string
      size_gb   = number
      iops      = optional(number)
      encrypted = optional(bool)
    })
    additional_volumes = optional(list(object({
      mount_point   = string
      size_gb       = number
      iops          = optional(number)
      type          = string
      encrypted     = optional(bool)
      filesystem    = optional(string)
      mount_options = optional(string)
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "databases" {
  type = map(object({
    region         = string
    zone           = string
    engine         = string
    engine_version = number
    instance_type  = string
    dbname         = string
    username       = string
    password       = string
    port           = number
    volume = object({
      size_gb   = number
      type      = string
      iops      = number
      encrypted = bool
    })
    settings = optional(list(object({
      name  = string
      value = number
    })), [])
    tags          = optional(map(string), {})
    public_access = optional(bool, false)
  }))
  default = {}
}

variable "alloy" {
  type = map(object({
    region    = string
    cpu_count = number
    password  = string
    settings = optional(list(object({
      name  = string
      value = string
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "biganimal" {
  type = map(object({
    project = optional(object({
      id = optional(string)
    }), {})
    password = optional(string)
    image = optional(object({
      pg    = optional(string)
      proxy = optional(string)
    }), {})
    data_groups = optional(map(object({
      cloud_account  = optional(bool)
      type           = string
      region         = string
      node_count     = number
      engine         = string
      engine_version = number
      instance_type  = string
      volume = object({
        size_gb    = number
        type       = string
        properties = string
        iops       = optional(number)
        throughput = optional(number)
      })
      wal_volume = optional(object({
        size_gb    = number
        type       = string
        properties = string
        iops       = optional(number)
        throughput = optional(number)
      }))
      pgvector = optional(bool)
      settings = optional(list(object({
        name  = string
        value = string
      })), [])
      allowed_ip_ranges = optional(list(object({
        cidr_block  = string
        description = optional(string, "default description")
      })))
      allowed_machines = optional(list(string))
    })))
    witness_groups = optional(map(object({
      region                 = string
      cloud_account          = optional(bool)
      cloud_service_provider = string
    })), {})
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "kubernetes" {
  type = map(object({
    region        = string
    zone_name     = string
    node_count    = number
    instance_type = string
    tags          = optional(map(string), {})
  }))
  default = {}
}
