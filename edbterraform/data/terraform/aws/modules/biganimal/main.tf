resource "biganimal_cluster" "instance" {

    # required 
    cloud_provider = local.cloud_provider
    cluster_architecture {
        id = var.cluster_type
        nodes = var.node_count
    }
    cluster_name = local.cluster_name
    instance_type = local.instance_type
    password = var.password
    pg_type = var.engine
    pg_version = var.engine_version
    project_id = var.project.id
    region = var.region
    storage {
        volume_type = var.volume.type
        volume_properties = var.volume.properties
        size = local.volume_size
        # optional
        iops = var.volume.iops
        throughput = var.volume.throughput
    }

    # optional
    dynamic "allowed_ip_ranges" {
        for_each = { for key,values in var.allowed_ip_ranges: key=>values }
        content {
            cidr_block = allowed_ip_ranges.value.cidr_block
            description = allowed_ip_ranges.value.description
        }
    }
    backup_retention_period = "1d"
    csp_auth = false
    dynamic "pg_config" {
        for_each = { for key,values in var.settings: key=>values } 
        content {
            name         = pg_config.value.name
            value        = pg_config.value.value
        }
    }
    private_networking = !var.publicly_accessible
    read_only_connections = false
}

locals {
  /*
  BigAnimal does not output the VPC id as it shares a VPC for all clusters within a project
  - Currently it has the following VPC name format: vpc-<project_id>-<region>
  - the resource will contain the project id: prj_<project_id>
  */
  base_project_id = trimprefix(biganimal_cluster.instance.project_id, "prj_")
  vpc_name = format("vpc-%s-%s", local.base_project_id, biganimal_cluster.instance.region)
  vpc_cmd = "aws ec2 describe-vpcs --filter Name=tag:Name,Values=${local.vpc_name} --query Vpcs[] --output json --region ${biganimal_cluster.instance.region}"
  extract_vpc_id = "jq -r .[].VpcId"
  extract_biganimal_id = "jq -r '.[].Tags[] | select(.Key == \"BAID\") | .Value'"

  /*
  BigAnimal creates 3 buckets. 2 are accessible with a private endpoint after being activated on the account.
  When using a cloud_account, we can attempt to find the buckets
  */
  // postgres bucket - pg-bucket-<project_id>-<region>/<cluster_id>/
  // Will contain base and wals directory
  postgres_bucket = format("pg-bucket-%s-%s", local.base_project_id, biganimal_cluster.instance.region)
  postgres_bucket_prefix = biganimal_cluster.instance.cluster_id
  // container logs bucket will need to be queried as each node will have a different directory suffix
  // Bucket may not not be available for some time after provisioning completes
  container_bucket = format("logs-bucket-%s-%s", local.base_project_id, biganimal_cluster.instance.region)
  partial_container_prefix = format("kubernetes-logs/customer_postgresql_cluster.var.log.containers.%s", biganimal_cluster.instance.cluster_id)
  // metrics logs bucket
  // directory prefix unknown
  metrics_bucket = format("metrics-bucket-%s-%s", local.base_project_id, biganimal_cluster.instance.region)
}

resource "toolbox_external" "vpc" {
  count = var.cloud_account ? 1 : 0
  program = [
    "bash",
    "-c",
    <<-EOT
    # Execute Script
    CMD="${local.vpc_cmd}"
    RESULT=$($CMD)
    RC=$?
    if [[ $RC -ne 0 ]];
    then
      printf "%s\n" "$RESULT" 1>&2
      exit $RC
    fi

    jq -n --arg vpc_id "$(printf %s "$RESULT" | ${local.extract_vpc_id})" \
          --arg biganimal_id "$(printf %s "$RESULT" | ${local.extract_biganimal_id})" \
          '{"vpc_id": $vpc_id, "biganimal_id": $biganimal_id}'
    EOT
  ]
}
