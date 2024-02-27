resource "biganimal_cluster" "instance" {
    count = length(var.wal_volume) > 0 ? 0 : 1
    # required 
    cloud_provider = local.cloud_provider
    cluster_architecture {
        id = var.cluster_type
        nodes = var.cluster_type == "single" ? 1 : var.node_count
    }
    cluster_name = local.cluster_name
    instance_type = local.instance_type
    password = var.password
    pg_type = var.engine
    pg_version = var.engine_version
    pgvector = var.pgvector
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
        for_each = local.allowed_ip_ranges
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
    superuser_access = true
}

resource "toolbox_external" "api" {
  count = length(var.wal_volume) > 0 ? 1 : 0
  create = true
  read = false
  update = false
  delete = true
  program = [
    "bash",
    "-c",
    <<EOT
    set -eou pipefail

    create_stage() {
      URI="https://portal.biganimal.com/"
      ENDPOINT="api/v3/projects/${var.project.id}/clusters"
      REQUEST_TYPE="POST"
      DATA='${jsonencode(local.API_DATA)}'
      RESULT=$(curl --silent --show-error --fail-with-body --location --request $REQUEST_TYPE --header "content-type: application/json" --header "$AUTH_HEADER" --url "$URI$ENDPOINT" --data "$DATA")
      RC=$?
      if [[ $RC -ne 0 ]];
      then
        printf "%s\n" "$RESULT" 1>&2
        exit $RC
      fi

      CLUSTER_DATA=$RESULT

      # Check cluster status
      ENDPOINT="api/v3/projects/${var.project.id}/clusters/$(printf %s "$CLUSTER_DATA" | jq -r .data.clusterId)"
      REQUEST_TYPE="GET"
      PHASE="creating"
      # Wait 30 minutes for cluster to be healthy
      COUNT=0
      COUNT_LIMIT=120
      SLEEP_TIME=15
      while [[ $PHASE != *"healthy"* ]]
      do
        RESULT=$(curl --silent --show-error --fail-with-body --location --request $REQUEST_TYPE --header "content-type: application/json" --header "$AUTH_HEADER" --url "$URI$ENDPOINT")
        RC=$?
        if [[ $RC -ne 0 ]]
        then
          printf "%s\n" "$RESULT" 1>&2
          exit $RC
        fi
        PHASE=$(printf "$RESULT" | jq -r .data.phase)

        if [[ $COUNT -gt COUNT_LIMIT ]] && [[ $PHASE != *"healthy"* ]]
        then
          printf "Cluster creation timed out\n" 1>&2
          printf "Last phase: $PHASE\n" 1>&2
          printf "Cluster data: $CLUSTER_DATA\n" 1>&2
          exit 1
        fi

        COUNT=$((COUNT+1))
        sleep $SLEEP_TIME
      done

      printf "$RESULT"
    }

    delete_stage() {
      URI="https://portal.biganimal.com/"
      ENDPOINT="api/v3/projects/${var.project.id}/clusters/$1"
      REQUEST_TYPE="DELETE"
      RESULT=$(curl --silent --show-error --fail-with-body --location --request $REQUEST_TYPE --header "content-type: application/json" --header "$AUTH_HEADER" --url "$URI$ENDPOINT")
      RC=$?
      if [[ $RC -ne 0 ]];
      then
        printf "%s\n" "$RESULT" 1>&2
        exit $RC
      fi

      printf '{"done":"%s"}' "$RESULT"
    }

    # Get json object from stdin
    IFS='' read -r input || [ -n "$input" ]

    # BigAnimal API accepts either an access key or a bearer token
    # The access token should be preferred if set and non-empty.
    AUTH_HEADER=""
    if [ ! -z "$${BA_ACCESS_KEY:+''}" ]
    then
      AUTH_HEADER="x-access-key: $BA_ACCESS_KEY"
    else
      AUTH_HEADER="authorization: Bearer $BA_BEARER_TOKEN"
    fi

    # Check CRUD stage from terraform
    # and make appropriate calls
    STAGE=$(printf "%s" "$input" | jq -r '.stage')
    case $STAGE in
      create)
        create_stage
        ;;
      read)
        ;;
      update)
        ;;
      delete)
        CLUSTER_ID=$(printf "%s" "$input" | jq -r '.old_result.data.clusterId')
        delete_stage "$CLUSTER_ID"
        ;;
      *)
        printf "Input: %s\n" "$input" 1>&2
        printf "Invalid stage: %s\n" "$STAGE" 1>&2
        exit 1
        ;;
    esac

    EOT
  ]
}

locals {
  cluster_output = length(var.wal_volume) > 0 ? jsondecode(toolbox_external.api.0.result.data) : biganimal_cluster.instance.0
  cluster_region = try(local.cluster_output.region.regionId, local.cluster_output.region)
  cluster_id = try(local.cluster_output.clusterId, local.cluster_output.cluster_id)
  /*
  BigAnimal does not output the VPC id as it shares a VPC for all clusters within a project
  - Currently it has the following VPC name format: vpc-<project_id>-<region>
  - the resource will contain the project id: prj_<project_id>
  */
  base_project_id = trimprefix(var.project.id, "prj_")
  vpc_name = format("vpc-%s-%s", local.base_project_id, local.cluster_region)
  vpc_cmd = "aws ec2 describe-vpcs --filter Name=tag:Name,Values=${local.vpc_name} --query Vpcs[] --output json --region ${local.cluster_region}"
  extract_vpc_id = "jq -r .[].VpcId"
  extract_biganimal_id = "jq -r '.[].Tags[] | select(.Key == \"BAID\") | .Value'"

  /*
  BigAnimal creates 3 buckets. 2 are accessible with a private endpoint after being activated on the account.
  When using a cloud_account, we can attempt to find the buckets
  */
  // postgres bucket - pg-bucket-<project_id>-<region>/<cluster_id>/
  // Will contain base and wals directory
  postgres_bucket = format("pg-bucket-%s-%s", local.base_project_id, local.cluster_region)
  postgres_bucket_prefix = local.cluster_id
  // container logs bucket will need to be queried as each node will have a different directory suffix
  // Bucket may not not be available for some time after provisioning completes
  container_bucket = format("logs-bucket-%s-%s", local.base_project_id, local.cluster_region)
  partial_container_prefix = format("kubernetes-logs/customer_postgresql_cluster.var.log.containers.%s", local.cluster_id)
  // metrics logs bucket
  // directory prefix unknown
  metrics_bucket = format("metrics-bucket-%s-%s", local.base_project_id, local.cluster_region)
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

    VPC_ID=$(printf "%s" "$RESULT" | ${local.extract_vpc_id})
    BIGANIMAL_ID=$(printf "%s" "$RESULT" | ${local.extract_biganimal_id})

    # BigAnimal main route table
    CMD="aws ec2 describe-route-tables --filter "Name=vpc-id,Values=$VPC_ID" --query RouteTables[?Associations[0].Main].RouteTableId --output text --region ${local.cluster_region}"
    RESULT=$($CMD)
    RC=$?
    if [[ $RC -ne 0 ]];
    then
      printf "%s\n%s\n" "$CMD" "$RESULT" 1>&2
      exit $RC
    fi

    MAIN_ROUTE_TABLE=$RESULT

    # BigAnimal uses private 3 route tables with the tags ManagedBy=BigAnimal and Name=*private*
    CMD="aws ec2 describe-route-tables --filter "Name=vpc-id,Values=$VPC_ID" --filter "Name=tag:ManagedBy,Values=BigAnimal" --filter "Name=tag:Name,Values=*private*"  --query RouteTables[].RouteTableId --output json --region ${local.cluster_region}"
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
    CMD="aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId==\'$VPC_ID\']" --region ${local.cluster_region} --output json"
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
