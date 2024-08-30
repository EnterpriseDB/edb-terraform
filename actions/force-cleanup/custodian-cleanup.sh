#!/bin/bash
set -eou pipefail
# Example call:
# $ PROVIDER=aws
# $ TAG_KEY=tag-key-name
# $ TAG_VALUE=tag-key-value
# $ REGIONS="us-east-1 us-west-2"
# $ custodian-cleanup.sh "$PROVIDER" "$TAG_KEY" "$TAG_VALUE" "$REGIONS"

# Inputs
PROVIDER="$1"
TAG_KEY="$2"
TAG_VALUE="$3"
REGIONS="${@:4}"

echo -e "Running custodian cleanup"
echo -e "Variables - Provider: $PROVIDER, Tag Key: $TAG_KEY, Tag Value: $TAG_VALUE, Regions: $REGIONS"

if [ -z "$PROVIDER" ] || [ -z "$TAG_KEY" ] || [ -z "$TAG_VALUE" ] || [ -z "$REGIONS" ]
then
  echo "Missing required variables for custodian cleanup"
  exit 1
fi

# Variables
SOURCEDIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
GENERATE_TEMPLATE="false"
IGNORE_LIST="$SOURCEDIR/ignore_resources.txt"
PREDEFINED_LIST="$SOURCEDIR/predefined_resources.txt"
POLICY_TEMPLATE="$SOURCEDIR/policy_template.yml"
POLICY_FILE="$SOURCEDIR/policy.yml"

# Check if custodian env is already setup
VENV_DIR="venv-custodian"
if [ ! -d "$VENV_DIR" ]
then
  python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
python -m pip install c7n > /dev/null

FINAL_TEMPLATE='
policies:
  - name: remove-ebs
    resource: aws.ebs
    filters:
      - type: value
        key: "tag:<TAG_KEY>"
        value: "<TAG_VALUE>"
        value_type: normalize
        op: equal
    actions:
      - type: delete
        force: true
  - name: remove-key-pairs
    resource: aws.key-pair
    filters:
      - unused
      - type: value
        key: "tag:<TAG_KEY>"
        value: "<TAG_VALUE>"
        value_type: normalize
        op: equal
    actions:
      - delete
'
TEMPLATE='
  - name: remove-<RESOURCE_NAME>
    resource: <RESOURCE>
    filters:
      - type: value
        key: "tag:<TAG_KEY>"
        value: "<TAG_VALUE>"
        value_type: normalize
        op: equal
    actions:
      - type: <OPERATION>
'

# Generate template
if [ "$GENERATE_TEMPLATE" == "true" ]
then
    echo "Generating policy templates"
    RESOURCE_TYPES=$(custodian schema "$PROVIDER" | cut -d'-' -f2- | tail -n+2 | head -n-1)
    PREDEFINED_RESOURCES="$(cat "$PREDEFINED_LIST")"
    IGNORE_RESOURCES="$(cat "$IGNORE_LIST")"
    for resource in $RESOURCE_TYPES
    do
        echo "$PREDEFINED_RESOURCES" | grep -qx "$resource" && echo "Predefined resource: $resource" && continue
        echo "$IGNORE_RESOURCES" | grep -qx "$resource" && echo "Ignoring resource: $resource" && continue
        # jq -r 'first(.definitions.actions | to_entries[] | select(.key == "aws.mark-for-op"))')
        SCHEMA=$(custodian schema $resource --json)
        #OPERATION=$(echo "$SCHEMA" | jq -r 'first(.definitions.resources | .[].actions | to_entries[] | select(.key == "terminate" or .key == "delete").key)')
        #MARK_OP_AVAILABLE=$(echo "$SCHEMA" | jq -r "select(.definitions.resources.\"$resource\".policy.allOf != null) | .definitions.resources.\"$resource\".policy.allOf[] | select(.properties.actions.items != null) | .properties.actions.items.anyOf[] | select(.enum != null) | .enum[] | select(. == \"mark-for-op\")")
        #[ "$MARK_OP_AVAILABLE" == "false" ] || [ "$MARK_OP_AVAILABLE" == "" ] || 
        OPERATION=$(echo "$SCHEMA" | jq -r "select(.definitions.resources.\"$resource\".policy.allOf != null) | .definitions.resources.\"$resource\".policy.allOf[] | select(.properties.actions.items != null) | .properties.actions.items.anyOf[] | select(.enum != null) | .enum | to_entries[] | select(.value == \"terminate\" or .value == \"delete\" or .value == \"delete-empty\").value")
        [ "$OPERATION" == "" ] && echo "Skipping resource, terminate/delete op missing: $resource" && continue
        echo "Adding resource: $resource"

        FINAL_TEMPLATE+=$(echo -e "$TEMPLATE" | \
                            sed -e "s|<RESOURCE_NAME>|${resource#aws.}|g" \
                                -e "s|<RESOURCE>|${resource}|g" \
                                -e "s|<OPERATION>|${OPERATION}|g" \
                        )
    done
    echo -e "$FINAL_TEMPLATE" > "$POLICY_TEMPLATE"
fi

# Generate policy file with tag key and value
sed -e "s|<TAG_KEY>|${TAG_KEY}|g" \
    -e "s|<TAG_VALUE>|${TAG_VALUE}|g" \
    "$POLICY_TEMPLATE" > "$POLICY_FILE"

for REGION in $REGIONS
do
    echo "Processing region: $REGION"
    case "$PROVIDER" in
        aws)
            RESOURCES=$(aws resourcegroupstaggingapi get-resources --tag-filters Key="$TAG_KEY",Values="$TAG_VALUE" --region "$REGION")
            RESOURCE_IDS=$(echo "$RESOURCES" | jq '.ResourceTagMappingList | .[] | .ResourceARN')
            RESOURCE_COUNT=$(echo "$RESOURCES" | jq '.ResourceTagMappingList | length')
            ;;
        azure)
            echo "Not supported" 1>&2
            exit 1
            ;;
        gcp)
            echo "Not supported" 1>&2
            exit 1
            ;;
        *)
            echo "Invalid provider: $PROVIDER"
            exit 1
            ;;
    esac

    if (( "$RESOURCE_COUNT" == 0 ))
    then
        echo "No resources found with tag: $TAG_KEY=$TAG_VALUE"
        continue
    else
        echo "Found resources: $RESOURCE_COUNT"
        echo "$RESOURCE_IDS"
    fi

    if ! custodian run --output-dir "out" --region "$REGION" "$POLICY_FILE"
    then
        {
            VPC_IDS=$(aws ec2 describe-vpcs --region "$REGION" --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" --query "Vpcs[].VpcId" --output text)
            for vpc_id in $VPC_IDS
            do
                echo "Deleting VPC dependencies: $vpc_id"

                ROUTE_IDS=$(aws ec2 describe-route-tables --region "$REGION" --filters "Name=vpc-id,Values=$vpc_id" "Name=association.main,Values=false" --query "RouteTables[].RouteTableId" --output text)
                for route_id in $ROUTE_IDS
                do
                    echo "Deleting route table and associations: $route_id"
                    ASSOCIATION_IDS=$(aws ec2 describe-route-tables --region "$REGION" --route-table-id "$route_id" --query "RouteTables[].Associations[].RouteTableAssociationId" --output text)
                    for association_id in $ASSOCIATION_IDS
                    do
                        aws ec2 disassociate-route-table --region "$REGION" --association-id "$association_id"
                    done
                    aws ec2 delete-route-table --region "$REGION" --route-table-id "$route_id"
                done

                GATEWAY_IDS=$(aws ec2 describe-internet-gateways --region "$REGION" --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" --query "InternetGateways[].InternetGatewayId" --output text)
                for gateway_id in $GATEWAY_IDS
                do
                    echo "Detaching and deleting internet gateway: $gateway_id"
                    aws ec2 detach-internet-gateway --region "$REGION" --internet-gateway-id "$gateway_id" --vpc-id "$vpc_id" || echo "Failed to detach internet gateway: $gateway_id"
                    aws ec2 delete-internet-gateway --region "$REGION" --internet-gateway-id "$gateway_id"
                done

                EGRESS_GATEWAY_IDS=$(aws ec2 describe-egress-only-internet-gateways --region "$REGION" --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" --query "EgressOnlyInternetGateways[].EgressOnlyInternetGatewayId" --output text)
                for egress_gateway_id in $EGRESS_GATEWAY_IDS
                do
                    echo "Deleting egress only internet gateway: $egress_gateway_id"
                    aws ec2 delete-egress-only-internet-gateway --region "$REGION" --egress-only-internet-gateway-id "$egress_gateway_id"
                done

                NACL_IDS=$(aws ec2 describe-network-acls --region "$REGION" --filters "Name=vpc-id,Values=$vpc_id" --query "NetworkAcls[?IsDefault != \`true\`].NetworkAclId" --output text)
                for nacl_id in $NACL_IDS
                do
                    echo "Deleting network acl: $nacl_id"
                    aws ec2 delete-network-acl --region "$REGION" --network-acl-id "$nacl_id"
                done

                DHCP_OPTIONS_IDS=$(aws ec2 describe-dhcp-options --region "$REGION" --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" --query "DhcpOptions[].DhcpOptionsId" --output text)
                for dhcp_options_id in $DHCP_OPTIONS_IDS
                do
                    echo "Deleting dhcp options: $dhcp_options_id"
                    aws ec2 delete-dhcp-options --region "$REGION" --dhcp-options-id "$dhcp_options_id"
                done

                SECURITY_GROUP_IDS=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$vpc_id" --query "SecurityGroups[?GroupName != \`default\`].GroupId" --output text)
                for sg_id in $SECURITY_GROUP_IDS
                do
                    echo "Deleting security group: $sg_id"
                    aws ec2 delete-security-group --region "$REGION" --group-id "$sg_id"
                done

                SUBNET_IDS=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$vpc_id" --query "Subnets[].SubnetId" --output text)
                for subnet_id in $SUBNET_IDS
                do
                    echo "Deleting subnet: $subnet_id"
                    aws ec2 delete-subnet --region "$REGION" --subnet-id "$subnet_id"
                done

                PEERING_CONNECTION_IDS=$(aws ec2 describe-vpc-peering-connections --region "$REGION" --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" --query "VpcPeeringConnections[].VpcPeeringConnectionId" --output text)
                for peering_connection_id in $PEERING_CONNECTION_IDS
                do
                    echo "Deleting vpc peering connection: $peering_connection_id"
                    aws ec2 delete-vpc-peering-connection --region "$REGION" --vpc-peering-connection-id "$peering_connection_id"
                done

                echo "Deleting VPC: $vpc_id"
                aws ec2 delete-vpc --region "$REGION" --vpc-id "$vpc_id"
            done
        } || echo -e "Manual VPC cleanup failed: $REGION"

        if ! custodian run --output-dir "out" --region "$REGION" --cache-period 0 "$POLICY_FILE"
        then
            echo "Failed to cleanup all resources in region: $REGION for tag: $TAG_KEY=$TAG_VALUE"
        fi
    else
        echo "Initial custodian run successful"
    fi

    case "$PROVIDER" in
        aws)
            RESOURCES=$(aws resourcegroupstaggingapi get-resources --tag-filters Key="$TAG_KEY",Values="$TAG_VALUE" --region "$REGION")
            RESOURCE_IDS=$(echo "$RESOURCES" | jq '.ResourceTagMappingList | .[] | .ResourceARN')
            RESOURCE_COUNT=$(echo "$RESOURCES" | jq '.ResourceTagMappingList | length')
            echo "$RESOURCE_COUNT resources found with tag: $TAG_KEY=$TAG_VALUE"
            echo "This may be inaccurate since the api is 'eventually consistent'"
            echo "https://github.com/aws/aws-sdk/issues/302"
            echo "https://github.com/aws/aws-sdk/issues/676"
            ;;
        azure)
            echo "Not supported" 1>&2
            exit 1
            ;;
        gcp)
            echo "Not supported" 1>&2
            exit 1
            ;;
        *)
            echo "Invalid provider: $PROVIDER"
            exit 1
            ;;
    esac
done

echo "Done"
