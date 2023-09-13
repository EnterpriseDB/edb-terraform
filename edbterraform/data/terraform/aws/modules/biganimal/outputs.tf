locals {
    // https://github.com/hashicorp/terraform/issues/23893#issuecomment-577963377
    // https://datatracker.ietf.org/doc/html/rfc3986#appendix-B
    pattern = "(?:(?P<scheme>[^:/?#]+):)?(?://(?P<authority>[^/?#]*))?(?P<path>[^?#]*)(?:\\?(?P<query>[^#]*))?(?:#(?P<fragment>.*))?"
    uri_split = regex(local.pattern, biganimal_cluster.instance.connection_uri)
    username = split("@", local.uri_split.authority)[0]
    port = split(":", local.uri_split.authority)[1]
    domain = trimsuffix(trimprefix(local.uri_split.authority, "${local.username}@"), ":${local.port}")
    dbname = split("/", local.uri_split.path)[1]
}

output "project_id" {
    value = biganimal_cluster.instance.project_id
}

output "cluster_id" {
    value = biganimal_cluster.instance.cluster_id
}

output "cloud_provider" {
  value = biganimal_cluster.instance.cloud_provider
}

output "cluster_name" {
    value = biganimal_cluster.instance.cluster_name
}

output "cluster_type" {
    value = biganimal_cluster.instance.cluster_type
}

output "cluster_architecture" {
    value = biganimal_cluster.instance.cluster_architecture
}

output "region" {
  value = biganimal_cluster.instance.region
}

output "dbname" {
    value = local.dbname
}

output "username" {
  value = local.username
}

output "password" {
  sensitive = true
  value = biganimal_cluster.instance.password
}

output "port" {
  value = local.port
}

output "private_ip" {
  value = biganimal_cluster.instance.private_networking ? local.domain : null
}

output "public_ip" {
  value = biganimal_cluster.instance.private_networking ? null : local.domain
}

output "engine" {
  value = biganimal_cluster.instance.pg_type
}

output "version" {
  value = biganimal_cluster.instance.pg_version
}

output "instance_type" {
  value = biganimal_cluster.instance.instance_type
}

output "connection_uri" {
  value = biganimal_cluster.instance.connection_uri
}

output "read_only_uri" {
    value = biganimal_cluster.instance.ro_connection_uri
}

output "tags" {
  value = var.tags
}

output "vpc_name" {
  value = local.vpc_name
}

output "vpc_id" {
  value = toolbox_external.vpc_id.result.id
}

output "all" {
    value = biganimal_cluster.instance
}
