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
  vpc_name = format("vpc-%s-%s",trimprefix(biganimal_cluster.instance.project_id, "prj_"), biganimal_cluster.instance.region)
  vpc_cmd = "aws ec2 describe-vpcs --filter Name=tag:Name,Values=${local.vpc_name} --query Vpcs[].VpcId --output text --region ${biganimal_cluster.instance.region}"
}

resource "toolbox_external" "vpc_id" {
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

    jq -n --arg result "$RESULT" '{"id": $result}'
    EOT
  ]
}
