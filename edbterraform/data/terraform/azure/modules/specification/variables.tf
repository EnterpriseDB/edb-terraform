variable "spec" {
  type = object({
    ssh_user     = string
    cluster_name = string
    operating_system = optional(object({
      publisher  = string
      offer = string
      sku = string
      version = string
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
        name        = string
        port        = optional(number)
        protocol    = string
        description = string
      })), [])
    }))
    machines = optional(map(object({
      type          = string
      region        = string
      zone          = number
      instance_type = string
      volume = object({
        type      = string
        size_gb   = number
      })
      additional_volumes = optional(list(object({
        mount_point = string
        size_gb     = number
        iops        = optional(number)
        type        = string
      })), [])
    })), {})
  })
}
