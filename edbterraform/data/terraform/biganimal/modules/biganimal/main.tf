resource "biganimal_cluster" "instance" {
    for_each = local.use_api || local.use_pgd ? {} : local.data_groups
    # required
    cloud_provider = each.value.cloud_provider_id
    cluster_architecture = {
        id = each.value.type
        nodes = each.value.node_count
    }
    cluster_name = local.cluster_name
    instance_type = each.value.instance_type
    password = local.password
    pg_type = each.value.engine
    pg_version = each.value.engine_version
    pgvector = each.value.pgvector
    project_id = var.project.id
    region = each.value.region
    storage = {
        volume_type = each.value.volume.type
        volume_properties = each.value.volume.properties
        size = each.value.volume.size
        # optional
        iops = each.value.volume.iops
        throughput = each.value.volume.throughput
    }

    # optional
    volume_snapshot_backup = false
    allowed_ip_ranges = each.value.allowed_ip_ranges
    backup_retention_period = "1d"
    csp_auth = false
    pg_config = each.value.settings
    private_networking = !var.publicly_accessible
    read_only_connections = false
    superuser_access = each.value.superuser_access
    maintenance_window = each.value.maintenance_window

    tags = local.tags

    timeouts {
      create = "75m"
    }
}

resource "biganimal_pgd" "clusters" {
    count = local.use_api || !local.use_pgd ? 0 : 1

    # required
    cluster_name = local.cluster_name
    project_id = var.project.id
    password = local.password

    data_groups = [
      for key, values in local.data_groups: {
        cloud_provider = {
          cloud_provider_id = values.cloud_provider_id
        }
        cluster_architecture = {
            cluster_architecture_id = values.type
            nodes = values.node_count
        }
        instance_type = { 
          instance_type_id = values.instance_type
        }
        pg_type = {
          pg_type_id = values.engine
        }
        pg_version = {
          pg_version_id = values.engine_version
        }
        project_id = var.project.id
        region = {
          region_id = values.region
        }
        storage = {
            volume_type = values.volume.type
            volume_properties = values.volume.properties
            size = values.volume.size
            # optional
            iops = values.volume.iops
            throughput = values.volume.throughput
        }

        # optional
        allowed_ip_ranges = values.allowed_ip_ranges
        pg_config = values.settings

        pe_allowed_principled_ids = []
        service_account_ids = contains(["gcp"], var.cloud_provider) ? [] : null

        backup_retention_period = "1d"
        csp_auth = false
        private_networking = !var.publicly_accessible
        read_only_connections = false
        superuser_access = values.superuser_access
        maintenance_window = values.maintenance_window
      }
    ]

    witness_groups = [
      for k,v in local.witness_groups: {
        region = {
          region_id = v.region
        }
        cloud_provider = {
          cloud_provider_id = v.cloud_provider_id
        }
        maintenance_window = v.maintenance_window
      }
    ]

    tags = local.tags

  lifecycle {
    precondition {
      error_message = "Witness group must be set when using 2 data groups with pgd"
      condition = length(local.data_groups) <= 1 || length(var.witness_groups) > 0
    }
  }

  timeouts {
    create = "75m"
  }
}

resource "toolbox_external" "api_biganimal" {
  count = local.use_api ? 1 : 0
  create = true
  read = false
  update = false
  delete = true
  program = [
    "bash",
    "-c",
    <<EOT
    set -eou pipefail
    # https://github.com/EnterpriseDB/terraform-provider-toolbox/issues/47
    # Handle deletion within trap once issue is resolved.
    trap 'echo "Allow process to finish. Use a 2nd interrupt and terraform will force kill the process" 1>&2' SIGTERM SIGINT SIGHUP SIGUSR1 SIGUSR2 SIGABRT SIGQUIT SIGPIPE SIGALRM SIGTSTP SIGTTIN SIGTTOU

    URI="${data.external.ba_api_access.result.ba_api_uri}"
    CLUSTER_NAME="${jsonencode(local.API_DATA.clusterName)}"

    cluster_exists_check() {
      # Check if the cluster already exists
      # Returns a string with the cluster id if it exists, 'false' if it does not
      local CLUSTER_NAME="$1"
      ENDPOINT="projects/${var.project.id}/clusters?name=$CLUSTER_NAME"
      REQUEST_TYPE="GET"
      if ! RESULT=$(curl --silent --show-error --fail-with-body --location --request $REQUEST_TYPE --header "content-type: application/json" --header "$AUTH_HEADER" --url "$URI/$ENDPOINT" 2>&1)
      then
        RC="$${PIPESTATUS[0]}"
        printf "URI: %s\n" "$URI" 1>&2
        printf "ENDPOINT: %s\n" "$ENDPOINT" 1>&2
        printf "REQUEST_TYPE: %s\n" "$REQUEST_TYPE" 1>&2
        printf "ERROR: %s\n" "$RESULT" 1>&2
        exit "$RC"
      fi

      CLUSTER_FOUND=$(echo $RESULT | jq -e '.data | length == 0' 2>&1)
      case "$CLUSTER_FOUND" in
        true)
          printf "false"
          ;;
        false)
          printf "$(echo $RESULT | jq -r '.data[0].clusterId')"
          ;;
        *)
          printf "ERROR: %s\n" "$CLUSTER_FOUND" 1>&2
          printf "API RESULT: %s\n" "$RESULT" 1>&2
          exit 1
          ;;
      esac
    }

    create_stage() {
      if CLUSTER_ID="$(cluster_exists_check "$CLUSTER_NAME")" && [[ "$CLUSTER_ID" != "false" ]]
      then
        printf "Cluster %s already exists with id %s\n" "$CLUSTER_NAME" "$CLUSTER_ID" 1>&2
        exit 1
      fi

      ENDPOINT="projects/${var.project.id}/clusters"
      REQUEST_TYPE="POST"
      DATA='${jsonencode(local.API_DATA)}'

      COUNT=0
      LIMIT=3
      while (( COUNT < LIMIT ))
      do
        if ! RESULT=$(curl --silent --show-error --fail-with-body --location --request $REQUEST_TYPE --header "content-type: application/json" --header "$AUTH_HEADER" --url "$URI/$ENDPOINT" --data "$DATA" 2>&1) \
          && ! $(echo $RESULT | grep -q "failed to ValidateQuota")
        then
          RC="$${PIPESTATUS[0]}"
          printf "URI: %s\n" "$URI" 1>&2
          printf "ENDPOINT: %s\n" "$ENDPOINT" 1>&2
          printf "REQUEST_TYPE: %s\n" "$REQUEST_TYPE" 1>&2
          printf "DATA: %s\n" "$DATA" 1>&2
          printf "ERROR: %s\n" "$RESULT" 1>&2

          # Delete cluster if it was left in a failed state
          if CLUSTER_ID=$(cluster_exists_check "$CLUSTER_NAME") && [[ "$CLUSTER_ID" != "false" ]]
          then
            printf "Cluster %s with id %s left in a failed state.\nDeleting cluster\n" "$CLUSTER_NAME" "$CLUSTER_ID" 1>&2
            delete_stage "$CLUSTER_ID" 1>&2
          fi

          exit "$RC"
        fi

        # Exit with result if no retry is needed
        if ! $(echo $RESULT | grep -q "failed to ValidateQuota")
        then
          printf "%s" "$RESULT"
          exit 0
        fi

        COUNT=$((COUNT+1))
        # Spread out retries to avoid hitting rate limits when calling the cluster creation endpoint across different projects at the same time
        sleep "$(( RANDOM % 30 + 1 ))"
      done

      printf "Failed to create cluster after %s attempts\n" "$LIMIT" 1>&2
      printf "DATA: %s\n" "$DATA" 1>&2
      printf "ERROR: %s\n" "$RESULT" 1>&2
      exit 1
    }

    delete_stage() {
      ENDPOINT="projects/${var.project.id}/clusters/$1"
      REQUEST_TYPE="DELETE"
      if ! RESULT=$(curl --silent --show-error --fail-with-body --location --request $REQUEST_TYPE --header "content-type: application/json" --header "$AUTH_HEADER" --url "$URI/$ENDPOINT" 2>&1)
      then
        # Skip error if cluster does not exist
        if $(echo $RESULT | grep -q "no such cluster")
        then
          RESULT="cluster does not exist"
        else
          RC="$${PIPESTATUS[0]}"
          printf "new error" 1>&2
          printf "%s\n" "$RESULT" 1>&2
          exit "$RC"
        fi
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
        # Wait for cluster to be deleted to avoid destroy-create race condition
        sleep 60
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

resource "toolbox_external" "api_status" {
  count = local.use_api ? 1 : 0
  create = true
  read = false
  update = false
  delete = false
  program = [
    "bash",
    "-c",
    <<EOT
    set -eou pipefail

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

    URI="${data.external.ba_api_access.result.ba_api_uri}"
    # Check cluster status
    ENDPOINT="projects/${var.project.id}/clusters/${jsondecode(toolbox_external.api_biganimal.0.result.data).clusterId}"
    REQUEST_TYPE="GET"
    PHASE="creating"
    # Wait 75 minutes for cluster to be healthy
    COUNT=0
    COUNT_LIMIT=300
    SLEEP_TIME=15
    while [[ $PHASE != *"healthy"* ]]
    do
      if ! RESULT=$(curl --silent --show-error --fail-with-body --location --request $REQUEST_TYPE --header "content-type: application/json" --header "$AUTH_HEADER" --url "$URI/$ENDPOINT" 2>&1) \
        || ! PHASE=$(printf "%s" "$RESULT" | jq -er ".data.phase" 2>&1) \
        || ! $([[ $PHASE == *"Failed"* ]] && exit 1 || exit 0)
      then
        RC="$${PIPESTATUS[0]}"
        printf "Result: %s\n" "$RESULT" 1>&2
        printf "Phase: %s\n" "$${PHASE:-curl command failed, unused}" 1>&2
        exit "$RC"
      fi

      if [[ $COUNT -gt COUNT_LIMIT ]] && [[ $PHASE != *"healthy"* ]]
      then
        printf "Cluster creation timed out\n" 1>&2
        printf "Last phase: %s\n" "$PHASE" 1>&2
        printf "Cluster data: %s\n" "$RESULT" 1>&2
        exit 1
      fi

      COUNT=$((COUNT+1))
      sleep $SLEEP_TIME
    done
  
    printf "%s" "$RESULT"
    EOT
  ]
}

locals {
  group_var = local.use_api ? "groups" : "data_groups"
  region_var = local.use_api ? "regionId" : "region_id"
  cluster_type_var = local.use_api ? "clusterType" : "cluster_type"
  cluster_id_var = local.use_api ? "clusterId" : "cluster_id"
  cluster_output = local.use_api ? jsondecode(toolbox_external.api_status.0.result.data) : try(biganimal_pgd.clusters.0, one(values(biganimal_cluster.instance)))
  data_group_filtered = [for group in lookup(local.cluster_output, local.group_var, [local.cluster_output]): group if group[local.cluster_type_var] != "witness_group"]
  witness_group_filtered = [for group in lookup(local.cluster_output, local.group_var, [local.cluster_output]): group if group[local.cluster_type_var] == "witness_group"]
  connection_uris = try(local.data_group_filtered.*.connection.pgUri, local.data_group_filtered.*.connection_uri)
  cluster_region = try(local.data_group_filtered[*].region[local.region_var], local.data_group_filtered[*].region)
  cloud_provider = try(local.data_group_filtered.*.cloud_provider.cloud_provider_id, local.data_group_filtered.*.provider.cloudProviderId, local.data_group_filtered.*.cloud_provider)
  cluster_type = local.data_group_filtered[*][local.cluster_type_var]
  cluster_architecture = try(local.data_group_filtered.*.clusterArchitecture, local.data_group_filtered.*.cluster_architecture.cluster_architecture_id, local.data_group_filtered.*.cluster_architecture.id)
  cluster_name_final = try(local.cluster_output.clusterName, local.cluster_output.cluster_name)
  cluster_id = local.cluster_output[local.cluster_id_var]
  engines = try(local.data_group_filtered.*.pg_type.pg_type_id, local.data_group_filtered.*.pgType.pgTypeId, local.data_group_filtered.*.pg_type)
  versions = try(local.data_group_filtered.*.pg_version.pg_version_id, local.data_group_filtered.*.pgVersion.pgVersionId ,local.data_group_filtered.*.pg_version)
  instance_types = try(local.data_group_filtered.*.instance_type.instance_type_id, local.data_group_filtered.*.instanceType.instanceTypeId, local.data_group_filtered.*.instance_type)
  // Extract username, port, domain, dbname from connection uri
  // https://github.com/hashicorp/terraform/issues/23893#issuecomment-577963377
  // https://datatracker.ietf.org/doc/html/rfc3986#appendix-B
  pattern = "(?:(?P<scheme>[^:/?#]+):)?(?://(?P<authority>[^/?#]*))?(?P<path>[^?#]*)(?:\\?(?P<query>[^#]*))?(?:#(?P<fragment>.*))?"
  uri_split = [ for uri in local.connection_uris : regex(local.pattern, uri) ]
  username = [ for uri_split in local.uri_split : split("@", uri_split.authority)[0] ]
  port = [ for uri_split in local.uri_split : split(":", uri_split.authority)[1] ]
  domain = [ for index, uri_split in local.uri_split : trimsuffix(trimprefix(uri_split.authority, "${local.username[index]}@"), ":${local.port[index]}") ]
  dbname = [ for uri_split in local.uri_split : split("/", uri_split.path)[1] ]
  # region and pattern values will match index of uri_split
  data_group_output = {
    for index, region in local.cluster_region: region => {
      region = region
      host = local.domain[index]
      database = local.dbname[index]
      username = local.username[index]
      port = local.port[index]
      connection_uri = local.connection_uris[index]
      engine = local.engines[index]
      version = local.versions[index]
      instance_type = local.instance_types[index]
      cloud_provider = local.cloud_provider[index]
    }
  }

  /*
  BigAnimal does not output the VPC id as it shares a VPC for all clusters within a project
  - Currently it has the following VPC name format: vpc-<project_id>-<region>
  - the resource will contain the project id: prj_<project_id>
  */
  base_project_id = trimprefix(var.project.id, "prj_")
  vpc_name = try(format("vpc-%s-%s", local.base_project_id, local.cluster_region[0]), "unknown")
  vpc_cmd = try("aws ec2 describe-vpcs --filter Name=tag:Name,Values=${local.vpc_name} --query Vpcs[] --output json --region ${local.cluster_region[0]}", "")
  extract_vpc_id = "jq -r .[].VpcId"
  extract_biganimal_id = "jq -r '.[].Tags[] | select(.Key == \"BAID\") | .Value'"

  /*
  BigAnimal creates 3 buckets. 2 are accessible with a private endpoint after being activated on the account.
  When using a cloud_account, we can attempt to find the buckets
  */
  // postgres bucket - pg-bucket-<project_id>-<region>/<cluster_id>/
  // Will contain base and wals directory
  postgres_bucket = try(format("pg-bucket-%s-%s", local.base_project_id, local.cluster_region[0]), "unknown")
  postgres_bucket_prefix = local.cluster_id
  // container logs bucket will need to be queried as each node will have a different directory suffix
  // Bucket may not not be available for some time after provisioning completes
  container_bucket = try(format("logs-bucket-%s-%s", local.base_project_id, local.cluster_region[0]), "unknown")
  partial_container_prefix = try(format("kubernetes-logs/customer_postgresql_cluster.var.log.containers.%s", local.cluster_id), "unknown")
  // metrics logs bucket
  // directory prefix unknown
  metrics_bucket = try(format("metrics-bucket-%s-%s", local.base_project_id, local.cluster_region[0]), "unknown")
}

resource "toolbox_external" "vpc" {
  count = var.cloud_provider == "aws" && local.cloud_account_non_pgd ? 1 : 0
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
    CMD="aws ec2 describe-route-tables --filter "Name=vpc-id,Values=$VPC_ID" --query RouteTables[?Associations[0].Main].RouteTableId --output text --region ${try(local.cluster_region[0], "")}"
    RESULT=$($CMD)
    RC=$?
    if [[ $RC -ne 0 ]];
    then
      printf "%s\n%s\n" "$CMD" "$RESULT" 1>&2
      exit $RC
    fi

    MAIN_ROUTE_TABLE=$RESULT

    # BigAnimal uses private 3 route tables with the tags ManagedBy=BigAnimal and Name=*private*
    CMD="aws ec2 describe-route-tables --filter "Name=vpc-id,Values=$VPC_ID" --filter "Name=tag:ManagedBy,Values=BigAnimal" --filter "Name=tag:Name,Values=*private*"  --query RouteTables[].RouteTableId --output json --region ${try(local.cluster_region[0], "")}"
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
    CMD="aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId==\'$VPC_ID\']" --region ${format("%v", local.cluster_region[0])} --output json"
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
