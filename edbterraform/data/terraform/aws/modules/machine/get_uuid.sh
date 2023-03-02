#!/bin/bash

# Grab stdin with 'jq', which is the form of type map(string)
# decode values (needed to use anything besides strings) and 
# insert into an associative array
TERRAFORM_INPUT=$(jq '.')
declare -A INPUT_MAPPING
for key in $(echo "${TERRAFORM_INPUT}" | jq -r 'keys_unsorted|.[]'); do
    INPUT_MAPPING["$key"]=$(echo "$TERRAFORM_INPUT" | jq -r .[\"$key\"] | base64 -d)
done

# Wait for SSH to become available
MAX_TRYS=20
SLEEP=30
ATTEMPTS=0
while ((ATTEMPTS<MAX_TRYS)); do
    ssh-keyscan -p 22 "${INPUT_MAPPING["ip_address"]}" 2>/dev/null | grep ssh-rsa > /dev/null
    if [ $? -eq 0 ]; then
        break
    fi
    ((ATTEMPTS++))
    sleep $SLEEP
done
if ((ATTEMPTS >= MAX_TRYS)); then
  echo "Error: SSH not available: ATTEMPTS $ATTEMPTS" >&2
  exit 1
fi


# Grab UUIDs from remote machine
cmds="blkid"
ssh_out=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${INPUT_MAPPING["ssh_user"]}@${INPUT_MAPPING["ip_address"]} -i ${INPUT_MAPPING["key_path"]} "$cmds")
UUIDS=$(echo "$ssh_out" | grep ' UUID')

# Grab mountpoints from remote machine
cmds="[[ -e /etc/mtab ]] && cat /etc/mtab || cat /proc/mounts"
ssh_out=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${INPUT_MAPPING["ssh_user"]}@${INPUT_MAPPING["ip_address"]} -i ${INPUT_MAPPING["key_path"]} "$cmds")
MOUNT_POINTS=$ssh_out

# Create mapping of mount_point => uuid
declare -A MOUNT_UUIDS
while read -r uuid_line; do
    uuid=$(echo "$uuid_line" | awk -F ' UUID=' '{print $2}' | awk -F '"' '{print $2}')
    device_name=$(echo "$uuid_line" | awk -F ':' '{print $1}')
    mount_point=$(awk -v device=$device_name '$1==device {print $2}' <<< $MOUNT_POINTS)
    MOUNT_UUIDS["$mount_point"]="$uuid"
done < <(echo "$UUIDS")

# Create JSON object from MOUNT_UUIDS mapping
# type of map(string) expected in stdout by external resource
json='{}'
for key in "${!MOUNT_UUIDS[@]}"; do
    json=$( jq -n --arg json "$json" \
                  --arg key "$key" \
                  --arg value "${MOUNT_UUIDS["$key"]}" \
                  '$json | fromjson + { ($key): ($value) }' )
done
echo "$json"
