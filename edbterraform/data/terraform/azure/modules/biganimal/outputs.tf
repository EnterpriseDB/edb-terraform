locals {
    // https://github.com/hashicorp/terraform/issues/23893#issuecomment-577963377
    // https://datatracker.ietf.org/doc/html/rfc3986#appendix-B
    pattern = "(?:(?P<scheme>[^:/?#]+):)?(?://(?P<authority>[^/?#]*))?(?P<path>[^?#]*)(?:\\?(?P<query>[^#]*))?(?:#(?P<fragment>.*))?"
    uri_split = regex(local.pattern, try(local.cluster_output.connection.pgUri, local.cluster_output.connection_uri))
    username = split("@", local.uri_split.authority)[0]
    port = split(":", local.uri_split.authority)[1]
    domain = trimsuffix(trimprefix(local.uri_split.authority, "${local.username}@"), ":${local.port}")
    dbname = split("/", local.uri_split.path)[1]
}

output "project_id" {
    value = var.project.id
}

output "cluster_id" {
    value = local.cluster_id
}

output "cloud_provider" {
  value = try(local.cluster_output.provider.cloudProviderId, local.cluster_output.cloud_provider)
}

output "cluster_name" {
  value = try(local.cluster_output.clusterName, local.cluster_output.cluster_name)
}

output "cluster_type" {
  value = try(local.cluster_output.clusterType, local.cluster_output.cluster_type)
}


output "cluster_architecture" {
    value = try(local.cluster_output.clusterArchitecture, local.cluster_output.cluster_architecture)
}

output "region" {
  value = local.cluster_region
}

output "dbname" {
    value = local.dbname
}

output "username" {
  value = local.username
}

output "password" {
  sensitive = true
  value = var.password
}

output "port" {
  value = local.port
}

output "private_ip" {
  value = try(local.cluster_output.privateNetworking ,local.cluster_output.private_networking) ? local.domain : null
}

output "public_ip" {
  value = try(local.cluster_output.privateNetworking ,local.cluster_output.private_networking) ? null : local.domain
}

output "engine" {
  value = try(local.cluster_output.pgType.pgTypeId, local.cluster_output.pg_type)
}

output "version" {
  value = try(local.cluster_output.pgVersion.pgVersionId ,local.cluster_output.pg_version)
}

output "instance_type" {
  value = try(local.cluster_output.instanceType.instanceTypeId, local.cluster_output.instance_type)
}

output "connection_uri" {
  value = try(local.cluster_output.connection.pgUri, local.cluster_output.connection_uri)
}

output "read_only_uri" {
    value = try(local.cluster_output.connection.readOnlyPgUri, local.cluster_output.ro_connection_uri)
}

output "tags" {
  value = var.tags
}

output "vpc_name" {
  value = var.cloud_account ? local.vpc_name : ""
}

output "buckets" {
  value = var.cloud_account ? {
    postgres = {
      bucket = local.postgres_bucket
      prefix = local.postgres_bucket_prefix
    }
    container = {
      bucket = local.container_bucket
      prefix = local.partial_container_prefix
    }
    metrics = {
      bucket = local.metrics_bucket
    }
  } : {}
}

output "all" {
    value = local.cluster_output
}

output "resources" {
  value = {
    biganimal_cluster = {
      instance = biganimal_cluster.instance
    }
    toolbox_external = {
      api = toolbox_external.api
    }
  }
}
