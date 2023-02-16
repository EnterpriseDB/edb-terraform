variable "publisher" {}
variable "offer" {}
variable "plan" {}
variable "accept" {
  description = "Auto-approve new image use, must only be accepted once"
  type = bool
  default = false
  nullable = false
}
