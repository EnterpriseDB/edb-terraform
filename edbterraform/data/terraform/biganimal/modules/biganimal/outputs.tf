output "api_uri" {
    value = data.external.ba_api_access.result.ba_api_uri
}

output "project_id" {
    value = var.project.id
}

output "cluster_id" {
    value = local.cluster_id
}

output "cloud_provider" {
  value = local.cloud_provider
}

output "cluster_name" {
  value = local.cluster_name_final
}

output "cluster_type" {
  value = local.cluster_type
}

output "cluster_architecture" {
    value = local.cluster_architecture
}

output "region" {
  value = local.cluster_region
}

output "dbname" {
    value = one(toset(local.dbname))
}

output "username" {
  value = one(toset(local.username))
}

output "password" {
  sensitive = true
  value = local.password
}

output "port" {
  value = one(toset(local.port))
}

output "private_ip" {
  value = local.domain
}

output "public_ip" {
  value = local.domain
}

output "data_groups" {
  value = local.data_group_output

  precondition {
    condition = (
      length(values(local.data_groups)) == length(values(local.data_group_output))
      && length(values(local.data_groups)) == length(local.data_group_filtered)
    )
    error_message = "Output length must match the number of data groups set"
  }
}

output "engine" {
  value = local.engines
}

output "version" {
  value = local.versions
}

output "instance_type" {
  value = local.instance_types
}

output "connection_uri" {
  value = local.connection_uris
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
  value = local.witness_group_filtered
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
      api_biganimal = toolbox_external.api_biganimal
      api_status = toolbox_external.api_status
    }
  }
}
