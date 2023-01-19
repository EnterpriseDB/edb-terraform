variable "spec" {
  type = object({
    ssh_user     = optional(string)
    cluster_name = string
    operating_system = optional(object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    }))
    regions = map(object({
      cidr_block = string
      zones      = optional(map(string), {})
      service_ports = optional(list(object({
        name        = string
        port        = optional(number)
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
        type    = string
        size_gb = number
      })
      additional_volumes = optional(list(object({
        mount_point = string
        size_gb     = number
        iops        = optional(number)
        type        = string
      })), [])
    })), {})
    kubernetes = optional(map(object({
      region                          = string
      resourceGroupLocation           = optional(string)
      logAnalyticsWorkspaceLocation   = optional(string)
      zone                            = string
      nodeCount                       = number
      instance_type                   = string
      aksServicePrincipalAppId        = string
      aksServicePrincipalClientSecret = string
      logAnalyticsWorkspaceSku        = string
      solutionName                    = string
      publisherName                   = string
      tags                            = optional(map(string), {})
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
      (length(var.spec.machines) == 0 && length(var.spec.kubernetes) == 0) ||
      var.spec.ssh_user != null
    )
    error_message = <<-EOT
    ssh_user key must be defined within spec when machines or kubernetes is used
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
