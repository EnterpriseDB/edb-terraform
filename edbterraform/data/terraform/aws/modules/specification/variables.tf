variable "spec" {
  type = object({
    ssh_user     = string
    cluster_name = string
    operating_system = optional(object({
      name  = string
      owner = number
    }))
    regions = map(object({
      cidr_block = string
      zones      = map(string)
      service_ports = list(object({
        port        = number
        protocol    = string
        description = string
      }))
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
      volume = object({
        type      = string
        size_gb   = number
        iops      = optional(number)
        encrypted = bool
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
      settings = list(object({
        name  = string
        value = number
      }))
    })), {})
    aurora = optional(map(object({
      region         = string
      zones          = list(string)
      count          = number
      engine         = string
      engine_version = number
      instance_type  = string
      dbname         = string
      username       = string
      password       = string
      port           = number
      settings = list(object({
        name  = string
        value = string
      }))
    })), {})
  })

  validation {
    condition     = length(var.spec.machines) == 0 || var.spec.operating_system != null
    error_message = <<-EOT
    operating_system key must be defined within spec when machines are used
    EOT
  }
}
