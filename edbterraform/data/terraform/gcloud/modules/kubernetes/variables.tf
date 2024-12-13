variable "machine" {}
variable "region" {}
variable "cluster_name" {}
variable "subnetwork" {}
variable "network" {}
variable "node_count" {
  type = number
}
variable "name_id" { default = "0" }
variable "tags" {
  type    = map(string)
  default = {}
}
locals {
  # gcloud label restrictions:
  # - lowercase letters, numeric characters, underscores and dashes
  # - 63 characters max
  # to match other providers as close as possible,
  # we will do any needed handling and continue to treat
  # key-values as tags even though they are labels under gcloud
  labels = { for key,value in var.tags: key => lower(replace(value, ":", "_"))}
}

variable "cluster_version" {
  type = string
  default = "1.28"
  nullable = false
}
