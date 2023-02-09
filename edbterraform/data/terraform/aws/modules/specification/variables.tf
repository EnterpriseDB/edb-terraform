variable "spec" {
  type = object({
    # Project Level Tags to be merged with other tags
    tags = optional(object({
      cluster_name = optional(string, "AWS-Cluster")
      created_by   = optional(string, "EDB-Terraform-AWS")
    }), {})
    ssh_user = optional(string)
    ssh_key = optional(object({
      public_path  = optional(string)
      private_path = optional(string)
      output_name  = optional(string, "ssh-id_rsa")
      use_agent    = optional(bool, false)
    }), {})
    operating_system = optional(object({
      name  = string
      owner = number
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
      type          = optional(string)
      count         = optional(number, 1)
      region        = string
      zone          = string
      instance_type = string
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
      tags = optional(map(string), {})
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
      settings = optional(list(object({
        name  = string
        value = number
      })), [])
      tags = optional(map(string), {})
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
      settings = optional(list(object({
        name  = string
        value = string
      })), [])
      tags = optional(map(string), {})
    })), {})
    kubernetes = optional(map(object({
      region        = string
      node_count    = number
      instance_type = string
      tags          = optional(map(string), {})
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
        for machine in var.spec.machines :
        length(machine.additional_volumes) == 0 ||
        anytrue([for service_port in var.spec.regions[machine.region].service_ports :
          service_port.port == 22
        ])
      ])
    )
    error_message = (
      <<-EOT
When using machines with additional volumes, SSH must be open.
Ensure each region listed below has port 22 open under service_ports.
Region - Machine:
%{for name, spec in var.spec.machines~}
%{if length(spec.additional_volumes) != 0~}
  ${spec.region} - ${name}
%{endif~}
%{endfor~}
EOT
    )
  }
}
