#!/bin/bash
# This script creates a single lvm volume group from a list of devices using 'lsblk's output, excluding the root volume.
# 
# Cloud providers may pre-attach local storage to a machine and it must be formatted for use.
# Caution: many times pre-attached storage is considered ephemeral and may be lost on machine restart/stop depending on the providers implementation.
#
# Positional Inputs expected as base64encoded json:
#   $1 - edb-terraform machine's preattached_volumes object
#          preattached_volumes = optional(object({
#            required = optional(bool)
#            volume_group = optional(string)
#            mount_points = optional(map(object({
#              size = optional(string)
#              filesystem = optional(string)
#              mount_options = optional(string)
#          })), {})
#   $2 - lsblk json output for all volumes including the mount points
#          -o NAME,KNAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,SERIAL,MODEL,VENDOR,REV,LABEL,UUID,PARTTYPE,PARTLABEL,PARTUUID,SCHED
#
set -euo pipefail

_jq_key() {
    printf %s "$1" | jq -rc "$2"
}

# Install nvme-cli, jq, and xfsprogs
if [ -f /etc/redhat-release ]
then
    sudo yum clean all
    sudo yum install jq -y
fi
if [ -f /etc/debian_version ]
then
    export DEBIAN_FRONTEND="noninteractive"
    sudo apt-get update -y
    sudo apt-get install jq -y
fi

# Expects a base64encoded json object
PREATTACHED_VOLUMES=$(printf %s "$1" | base64 -d | jq -rc '.')
LSBLK_DEVICES=$(printf %s "$2" | base64 -d | jq -rc '.')

REQUIRED=$(_jq_key "$PREATTACHED_VOLUMES" '.required')
VOLUME_GROUP=$(_jq_key "$PREATTACHED_VOLUMES" '.volume_group')
MOUNT_POINTS=$(_jq_key "$PREATTACHED_VOLUMES" '.mount_points')
ROOT_VOLUME=$(printf %s "$LSBLK_DEVICES" | jq -rc '.blockdevices[] | select(.children[]?.mountpoint == "/") | .name')
REMAINING_VOLUMES=$(printf %s "$LSBLK_DEVICES" | jq -rc ".blockdevices[] | select(.name != \"$ROOT_VOLUME\") | .name")

if [ -z "${REMAINING_VOLUMES}" ] && [ "${REQUIRED}" = "false" ]
then
    printf "%s\n" "Warning: No remaining volumes to create volume group"
    exit 0
fi
if [ -z "${REMAINING_VOLUMES}" ] && [ "${REQUIRED}" = "true" ]
then
    printf "%s\n" "Error: No remaining volumes to create volume group" 1>&2
    exit 1
fi

# Install nvme-cli, jq, and xfsprogs
if [ -f /etc/redhat-release ]
then
    sudo yum install nvme-cli xfsprogs lvm2 -y
fi
if [ -f /etc/debian_version ]
then
    sudo apt-get install nvme-cli perl-modules xfsprogs lvm2 -y
fi

# Create lvm physical/group volumes
for device_name in ${REMAINING_VOLUMES}
do
    device_path="/dev/${device_name}"
    # Check if volume exists to either create or extend volume group
    if sudo vgs ${VOLUME_GROUP} >/dev/null 2>&1
    then
        VG_CMD=vgextend
    else
        VG_CMD=vgcreate
    fi
    sudo pvcreate "$device_path"
    sudo "${VG_CMD}" "${VOLUME_GROUP}" "$device_path"
done

# Create logical volumes, format volumes and mount volumes
_jq_key "${MOUNT_POINTS}" "keys[]" | \
while read -r MOUNT_POINT
do
    MOUNT_DATA=$(_jq_key "${MOUNT_POINTS}" ".\"${MOUNT_POINT}\"")
    SIZE=$(_jq_key "${MOUNT_DATA}" ".size")
    FILESYSTEM=$(_jq_key "${MOUNT_DATA}" '.filesystem')
    MOUNT_OPTIONS=$(_jq_key "${MOUNT_DATA}" '.mount_options')

    VOLUME_COUNT=$(sudo vgs -o pv_count --noheadings $VOLUME_GROUP | tr -d ' ')
    LV_NAME=$(printf "%s" "${MOUNT_POINT}" | tr '/' '_')
    LV_PATH="/dev/${VOLUME_GROUP}/${LV_NAME}"
    # Create the logical volume
    case "${SIZE}" in
        *%*)
            SIZE_CMD="--extents"
            ;;
        *)
            SIZE_CMD="--size"
            ;;
    esac

    sudo lvcreate "${SIZE_CMD}" "${SIZE}" --name "${LV_NAME}" --type striped --stripes "${VOLUME_COUNT}" "${VOLUME_GROUP}"
    # Create the filesystem
    sudo "mkfs.${FILESYSTEM}" "${LV_PATH}"
    # Create the mount point
    sudo mkdir -p "${MOUNT_POINT}"
    # Get device UUID with blkid as exported format:
    # UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    printf "%s\n" "Warning: Will be mounted by UUID in /etc/fstab"
    UUID=$(sudo blkid "${LV_PATH}" -o export | grep -E "^UUID=")
    printf "%s\n" "${UUID} ${MOUNT_POINT} ${FILESYSTEM} ${MOUNT_OPTIONS} 0 0" | sudo tee -a /etc/fstab
    sudo mount --all
done
