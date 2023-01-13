variable "spec" {
  type = object({
    ssh_user     = string
    cluster_name = string
    operating_system = optional(object({
      name = string
    }))
    regions = map(object({
      cidr_block = string
      zones      = optional(map(string), {})
      service_ports = optional(list(object({
        port        = number
        protocol    = string
        description = string
      })), [])
      region_ports = optional(list(object({
        port        = number
        protocol    = string
        description = string
      })), [])
    }))
    machines = optional(map(object({
      type          = string
      region        = string
      zone          = string
      instance_type = string
      ip_forward    = optional(bool, false)
      volume = object({
        type      = string
        size_gb   = number
        iops      = optional(number)
        encrypted = optional(bool, false)
      })
      additional_volumes = optional(list(object({
        mount_point = string
        size_gb     = number
        iops        = optional(number)
        type        = string
        encrypted   = bool
      })), [])
    })), {})
    databases = optional(map(object({
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
    })), {})
    alloy = optional(map(object({
      region    = string
      cpu_count = number
      password  = string
      settings = optional(list(object({
        name  = string
        value = string
      })), [])
    })), {})
  })
}
