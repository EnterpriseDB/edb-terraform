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
    walStorage {
	    volume_type = var.wal_volume.type
        volume_properties = var.wal_volume.properties
        size = local.wal_volume_size
        # optional
        iops = var.wal_volume.iops
        throughput = var.wal_volume.throughput
    }

    # optional
    dynamic "allowed_ip_ranges" {
        for_each = var.allowed_ip_ranges
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

    VPC_ID=$(printf %s "$RESULT" | ${local.extract_vpc_id})
    BIGANIMAL_ID=$(printf %s "$RESULT" | ${local.extract_biganimal_id})

    # BigAnimal main route table
    CMD="aws ec2 describe-route-tables --filter "Name=vpc-id,Values=$VPC_ID" --query RouteTables[?Associations[0].Main].RouteTableId --output text --region ${biganimal_cluster.instance.region}"
    RESULT=$($CMD)
    RC=$?
    if [[ $RC -ne 0 ]];
    then
      printf "%s\n%s\n" "$CMD" "$RESULT" 1>&2
      exit $RC
    fi

    MAIN_ROUTE_TABLE=$RESULT

    # BigAnimal uses private 3 route tables with the tags ManagedBy=BigAnimal and Name=*private*
    CMD="aws ec2 describe-route-tables --filter "Name=vpc-id,Values=$VPC_ID" --filter "Name=tag:ManagedBy,Values=BigAnimal" --filter "Name=tag:Name,Values=*private*"  --query RouteTables[].RouteTableId --output json --region ${biganimal_cluster.instance.region}"
    RESULT=$($CMD)
    RC=$?
    if [[ $RC -ne 0 ]];
    then
      printf "%s\n%s\n" "$CMD" "$RESULT" 1>&2
      exit $RC
    fi

    ROUTE_TABLE_0=$(printf "%s" $RESULT | jq -r .[0])
    ROUTE_TABLE_1=$(printf "%s" $RESULT | jq -r .[1])
    ROUTE_TABLE_2=$(printf "%s" $RESULT | jq -r .[2])

    # BigAnimal has a loadbalancer attached to the projects vpc
    CMD="aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId==\'$VPC_ID\']" --region ${biganimal_cluster.instance.region} --output json"
    RESULT=$($CMD)
    RC=$?
    if [[ $RC -ne 0 ]];
    then
      printf "%s\n%s\n" "$CMD" "$RESULT" 1>&2
      exit $RC
    fi

    LOADBALANCER_NAME=$(printf "%s" $RESULT | jq -r .[0].LoadBalancerName)
    LOADBALANCER_DNS=$(printf "%s" $RESULT | jq -r .[0].DNSName)

    jq -n --arg vpc_id "$VPC_ID" \
          --arg biganimal_id "$BIGANIMAL_ID" \
          --arg main_route_table_id "$MAIN_ROUTE_TABLE" \
          --arg route_0_id "$ROUTE_TABLE_0" \
          --arg route_1_id "$ROUTE_TABLE_1" \
          --arg route_2_id "$ROUTE_TABLE_2" \
          --arg loadbalancer_name "$LOADBALANCER_NAME" \
          --arg loadbalancer_dns "$LOADBALANCER_DNS" \
            '{"vpc_id": $vpc_id, "biganimal_id": $biganimal_id, "main_route_table_id": $main_route_table_id, "route_0_id": $route_0_id, "route_1_id": $route_1_id, "route_2_id": $route_2_id, "loadbalancer_name": $loadbalancer_name, "loadbalancer_dns": $loadbalancer_dns}'
    EOT
  ]
}
