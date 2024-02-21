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
      ports = optional(list(object({
        defaults     = optional(string, "")
        port        = optional(number)
        to_port     = optional(number)
        protocol    = string
        description = optional(string, "default")
        type = optional(string, "ingress")
        cidrs = optional(list(string), [])
      })), [])
    }))
    machines = optional(map(object({
      type          = optional(string)
      image_name    = string
      count         = optional(number, 1)
      spot          = optional(bool)
      region        = string
      ssh_port      = optional(number, 22)
      ports         = optional(list(object({
        defaults    = optional(string, "")
        port        = optional(number)
        to_port     = optional(number)
        protocol    = string
        description = optional(string, "default")
        type = optional(string, "ingress")
        cidrs = optional(list(string), [])
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
      # Creates a set of volumes around a machine instance to be attached post-terraform
      jbod_volumes = optional(map(object({
        type = string
        size_gb = number
        iops = optional(number)
        throughput = optional(number)
        encrypted = optional(bool)
      })))
      # Cloud providers may:
      #   * change order of volume attachment during reboot/stop
      #   * mount location can be ignored based on type
      #   * initial mount location can be set by the instance image
      # To track volumes, pre-formating is required to create a UUID on the volume.
      # Use jbod_volumes which are meant to represent "Just a bunch of Disks(Volumes)" as an alternative
      # to manually manage per machine instance post-terraform
      additional_volumes = optional(list(object({
        count         = optional(number, 1)
        mount_point   = optional(string)
        size_gb       = number
        iops          = optional(number)
        throughput    = optional(number)
        type          = string
        encrypted     = optional(bool)
        filesystem    = optional(string)
        mount_options = optional(string)
        volume_group  = optional(string)
      })), [])
      volume_groups = optional(map(map(object({
        size = optional(string)
        filesystem = optional(string)
        mount_options = optional(string)
      }))), {})
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
    biganimal = optional(map(object({
      type           = string
      project        = object({
        id = optional(string)
      })
      cloud_account = optional(bool)
      region         = string
      node_count     = number
      engine         = string
      engine_version = number
      instance_type  = string
      volume = object({
        size_gb   = number
        type      = string
        properties = string
        iops      = optional(number)
        throughput = optional(number)
      })
      wal_volume = optional(object({
        size_gb   = number
        type      = string
        properties = string
        iops      = optional(number)
        throughput = optional(number)
      }))
      password       = string
      pgvector       = optional(bool)
      settings = optional(list(object({
        name  = string
        value = string
      })), [])
      allowed_ip_ranges = optional(list(object({
        cidr_block = string
        description = optional(string, "default description")
      })))
      allowed_machines = optional(list(string))
      tags = optional(map(string), {})
    })), {})
    kubernetes = optional(map(object({
      region        = string
      node_count    = number
      instance_type = string
      tags          = optional(map(string), {})
    })), {})
  })
}

variable "force_ssh_access" {
  description = "Force append a service rule for ssh access"
  default = false
  type = bool
  nullable = false
}

locals {
  cluster_name = can(var.spec.tags.cluster_name) ? var.spec.tags.cluster_name : "AWS-Cluster-default"
  created_by = can(var.spec.tags.created_by) ? var.spec.tags.created_by : "EDB-Terraform-AWS"
}
