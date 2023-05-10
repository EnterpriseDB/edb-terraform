variable "spec" {
  description = <<-EOT
  Object meant to represent inputs needed to get a valid configuration
  for use with the rest of the cloud provider module collection.
  In most cases:
  * optional() should be used so that null is passed further down for the module to handle
    * Module require null to be handled:
      * set a default if desired: optional(type,default) 
    * Need to set a default after the initial object is set:
      * dynamically set variables with the use of locals and null_resource
      * set an output variable for use with other modules
  * sibling modules should handle most errors with variable validations and preconditions
    so they are caught during terraform plan
  * provider implementations vary and errors might need to be caught eariler, as last resort, 
    use validations and preconditions here for use with terraform plan or postconditions with terraform apply
  EOT
  type = object({
    # Project Level Tags to be merged with other tags
    tags = optional(map(string), {
      cluster_name = "AWS-Cluster-default"
      created_by   = "EDB-Terraform-AWS"
    })
    ssh_key = optional(object({
      public_path  = optional(string)
      private_path = optional(string)
      output_name  = optional(string, "ssh-id_rsa")
      use_agent    = optional(bool, false)
    }), {})
    images = optional(map(object({
      name = optional(string)
      owner = optional(string)
      ssh_user = optional(string)
    })))
    regions = map(object({
      cidr_block = string
      zones      = optional(map(object({
        zone = optional(string)
        cidr = optional(string)
      })), {})
      service_ports = optional(list(object({
        port        = optional(number)
        protocol    = string
        description = optional(string)
        type = optional(string, "ingress")
        cidrs = optional(list(string), ["0.0.0.0/0"])
      })), [])
      region_ports = optional(list(object({
        port        = optional(number)
        protocol    = string
        description = optional(string)
        type = optional(string, "ingress")
        cidrs = optional(list(string))
      })), [])
    }))
    machines = optional(map(object({
      type          = optional(string)
      image_name    = string
      count         = optional(number, 1)
      region        = string
      ssh_port      = optional(number, 22)
      ports         = optional(list(object({
        port        = optional(number)
        protocol    = string
        description = optional(string)
        type = optional(string, "ingress")
        cidrs = optional(list(string))
        })), []
      )
      zone_name     = string
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
    condition = can(var.spec.tags.cluster_name) && can(var.spec.tags.created_by)
    error_message = <<-EOT
    cluster_name and created_by need to be defined under tags
    Tags: ${jsonencode(var.spec.tags)}
    EOT
  }
}

locals {
  cluster_name = can(var.spec.tags.cluster_name) && length(var.spec.tags.cluster_name) > 0 ? var.spec.tags.cluster_name : "AWS-Cluster-default"
  created_by = can(var.spec.tags.created_by) && length(var.spec.tags.created_by) > 0 ? var.spec.tags.created_by : "EDB-Terraform-AWS"
}
