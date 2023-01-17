variable "spec" {
  type = object({
    ssh_user     = optional(string)
    cluster_name = string
    operating_system = optional(object({
      name = string
    }))
    regions = map(object({
      cidr_block = string
      zones      = optional(map(string), {})
      service_ports = optional(list(object({
        port        = optional(number)
        protocol    = string
        description = string
      })), [])
      region_ports = optional(list(object({
        port        = optional(number)
        protocol    = string
        description = string
      })), [])
    }))
    machines = optional(map(object({
      type          = string
      region        = string
      zone          = string
      instance_type = string
      ip_forward    = optional(bool)
      volume = object({
        type      = string
        size_gb   = number
        iops      = optional(number)
        encrypted = optional(bool)
      })
      additional_volumes = optional(list(object({
        mount_point = string
        size_gb     = number
        iops        = optional(number)
        type        = string
        encrypted   = optional(bool)
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
    gke = optional(map(object({
      region        = string
      zone          = string
      cpu_count     = number
      instance_type = string
    })), {})
  })

  validation {
    condition     = length(var.spec.machines) == 0 || var.spec.operating_system != null
    error_message = <<-EOT
    operating_system key must be defined within spec when machines are used
    EOT
  }

  validation {
    condition = (
      alltrue([
        for machine in var.spec.machines:
          length(machine.additional_volumes) == 0 ||
          anytrue([for service_port in var.spec.regions[machine.region].service_ports: 
            service_port.port == 22
        ])
      ])
    )
    error_message = (
<<-EOT
When using machines with additional volumes, SSH must be open.
Ensure each region listed below has port 22 open under service_ports.
Region - Machine:
%{ for name, spec in var.spec.machines ~}
%{ if length(spec.additional_volumes) != 0 ~}
  ${spec.region} - ${name}
%{ endif ~}
%{ endfor ~}
EOT
    )
  }

}
