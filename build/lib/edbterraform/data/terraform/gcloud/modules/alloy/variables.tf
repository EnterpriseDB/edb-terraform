variable "name" {}
variable "network" {}
variable "region" {}
variable "zone" {
  type     = string
  default  = ""
  nullable = false
}
variable "port" {
  type     = number
  default  = 5432
  nullable = false
}
variable "cpu_count" {
  type     = number
  default  = 2
  nullable = false
  validation {
    condition = (
      64 % var.cpu_count == 0 &&
      var.cpu_count >= 2
    )
    error_message = "cpu_count must be 2, 4, 8, 16, 32, 64"
  }
}
variable "username" {
  type      = string
  default   = "postgres"
  nullable  = false
  sensitive = true
}
variable "password" {}
variable "settings" {
  type = list(object({
    name  = string
    value = string
  }))

  validation {
    condition = alltrue([
      for setting in var.settings :
      setting.name != "max_connections" ||
      tonumber(setting.value) >= 1000
    ])
    error_message = "max_connections minimum allowed value: 1000"
  }

}
variable "automated_backups" {
  type     = bool
  default  = false
  nullable = false
}
variable "backup_count" {
  type     = number
  default  = 0
  nullable = false
}
variable "backup_start_time" {
  default = {
    hours   = 0
    minutes = 0
    seconds = 0
    nanos   = 0
  }
  nullable = false
}
variable "backup_days" {
  type     = list(string)
  default  = ["SUNDAY"]
  nullable = false
}
