locals {
    // https://github.com/hashicorp/terraform/issues/23893#issuecomment-577963377
    // https://datatracker.ietf.org/doc/html/rfc3986#appendix-B
    pattern = "(?:(?P<scheme>[^:/?#]+):)?(?://(?P<authority>[^/?#]*))?(?P<path>[^?#]*)(?:\\?(?P<query>[^#]*))?(?:#(?P<fragment>.*))?"
    uri_split = [ for uri in try([local.cluster_output.connection.pgUri], [local.cluster_output.connection_uri], local.cluster_output.data_groups.*.connection_uri) : regex(local.pattern, uri) ]
    username = [ for uri_split in local.uri_split : split("@", uri_split.authority)[0] ]
    port = [ for uri_split in local.uri_split : split(":", uri_split.authority)[1] ]
    domain = [ for index, uri_split in local.uri_split : trimsuffix(trimprefix(uri_split.authority, "${local.username[index]}@"), ":${local.port[index]}") ]
    dbname = [ for uri_split in local.uri_split : split("/", uri_split.path)[1] ]
}

output "project_id" {
    value = var.project.id
}

output "cluster_id" {
    value = local.cluster_id
}

output "cloud_provider" {
  value = try(local.cluster_output.provider.cloudProviderId, local.cluster_output.cloud_provider, one(toset(concat(local.cluster_output.data_groups.*.cloud_provider.cloud_provider_id))))
}

output "cluster_name" {
  value = try(local.cluster_output.clusterName, local.cluster_output.cluster_name)
}

output "cluster_type" {
  value = try(local.cluster_output.clusterType, local.cluster_output.cluster_type, distinct(local.cluster_output.data_groups.*.cluster_architecture.cluster_architecture_id))
}


output "cluster_architecture" {
    value = try(local.cluster_output.clusterArchitecture, local.cluster_output.cluster_architecture, "pgd")
}

output "region" {
  value = local.cluster_region
}

output "dbname" {
    value = try(one(local.dbname), one(toset(local.dbname)))
}

output "username" {
  value = try(one(local.username), one(toset(local.username)))
}

output "password" {
  sensitive = true
  value = local.password
}

output "port" {
  value = try(one(local.port), one(toset(local.port)))
}

output "private_ip" {
  value = local.domain
}

output "public_ip" {
  value = local.domain
}

output "engine" {
  value = try(local.cluster_output.pgType.pgTypeId, local.cluster_output.pg_type, local.cluster_output.data_groups.*.pg_type.pg_type_id)
}

output "version" {
  value = try(local.cluster_output.pgVersion.pgVersionId ,local.cluster_output.pg_version, local.cluster_output.data_groups.*.pg_version.pg_version_id)
}

output "instance_type" {
  value = try(local.cluster_output.instanceType.instanceTypeId, local.cluster_output.instance_type, local.cluster_output.data_groups.*.instance_type.instance_type_id)
}

output "connection_uri" {
  value = try(local.cluster_output.connection.pgUri, local.cluster_output.connection_uri, local.cluster_output.data_groups.*.connection_uri)
}

output "read_only_uri" {
    value = try(local.cluster_output.connection.readOnlyPgUri, local.cluster_output.ro_connection_uri, "unknown")
}

output "logs_url" {
  value = try(local.cluster_output.logsUrl, local.cluster_output.logs_url, local.cluster_output.data_groups.*.logs_url)
}

output "mertics_url" {
  value = try(local.cluster_output.metricsUrl, local.cluster_output.metrics_url, local.cluster_output.data_groups.*.metrics_url)
}

output "witness_groups" {
  value = try(local.cluster_output.witnessGroups, local.cluster_output.witness_groups, "")
}

output "tags" {
  value = var.tags
}

output "vpc_name" {
  value = can(toolbox_external.vpc.0) ? local.vpc_name : ""
}

output "vpc_id" {
  value = can(toolbox_external.vpc.0) ? toolbox_external.vpc.0.result.vpc_id : ""
}

output "biganimal_id" {
  value = can(toolbox_external.vpc.0) ? toolbox_external.vpc.0.result.biganimal_id : ""
}

output "buckets" {
  value = local.cloud_account_non_pgd ? {
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

output "loadbalancer" {
  value = can(toolbox_external.vpc.0) ? {
    name = toolbox_external.vpc.0.result.loadbalancer_name
    dns = toolbox_external.vpc.0.result.loadbalancer_dns
  } : {}
}

output "raw" {
    value = local.cluster_output
}

output "resources" {
  value = {
    biganimal_cluster = {
      instance = biganimal_cluster.instance
    }
    biganimal_pgd = {
      cluster = biganimal_pgd.clusters
    }
    toolbox_external = {
      vpc = toolbox_external.vpc
      api = toolbox_external.api
    }
  }
}
