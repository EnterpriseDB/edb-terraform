#!/bin/bash
set -euo pipefail

# Install nvme-cli, jq, and xfsprogs
if [ -f /etc/redhat-release ]; then
	sudo yum clean all
	sudo yum install nvme-cli jq xfsprogs -y
fi
if [ -f /etc/debian_version ]; then
	export DEBIAN_FRONTEND="noninteractive"
	sudo apt-get update -y
	sudo apt-get install nvme-cli jq perl-modules xfsprogs -y
fi

# Expects a base64encoded json object
SCRIPT_INPUTS=$(printf %s "$1" | base64 -d | jq -rc '.[]')
VOLUME_GROUPS=$(printf %s "$2" | base64 -d | jq -rc '.')

_jq_key() {
	printf %s "$1" | jq -rc "$2"
}

# Find volumes and create a filesystem or lvm volume groups
for item in ${SCRIPT_INPUTS}
do
	# Expected device paths: ["/dev/sdX","/dev/sdY"]
	TARGET_DEVICES=$(_jq_key "$item" '.device_names[]')

	# Mount point
	MOUNT_POINT=$(_jq_key "$item" '.mount_point')
	# Total number of nvme devices that should be present on the system
	N_NVME_DEVICE=$(_jq_key "$item" '.number_of_volumes')
	FSTYPE=$(_jq_key "$item" '.filesystem')
	FSMOUNTOPT=$(_jq_key "$item" '.mount_options')
	VOLUME_GROUP=$(_jq_key "$item" '.volume_group')

	# Wait for the availability of all the NVME devices that should be
	# present on the system.
	COUNTER=0
	while [ "$(sudo nvme list | tail -n +3 | wc -l)" -ne "${N_NVME_DEVICE}" ]; do
		sleep 2
		COUNTER=$((COUNTER + 1))
		if [ $COUNTER -ge 10 ]; then
			printf "%s\n" "ERROR: unable to get the full list of NVME devices after 20s"
			break
		fi
	done

	# Based on the target EBS device (/dev/sdX) we have to find the corresponding
	# NVME device.
	TARGET_NVME_DEVICE=""
	for NVME_DEVICE in $(sudo ls -1v /dev/nvme*n*); do
		FOUND_DEVICE=$(sudo nvme id-ctrl -v "${NVME_DEVICE}" | grep "0000:" | awk '{ print $18 }' | sed 's/["\.]//g')

		# /dev/ might be dropped at times so we need to check both cases
		for DEVNAME in ${TARGET_DEVICES[*]}; do
			if [ "${DEVNAME}" = "${FOUND_DEVICE}" ] || [ "${DEVNAME}" = "/dev/${FOUND_DEVICE}" ]; then
				TARGET_NVME_DEVICE=${NVME_DEVICE}
				break
			fi
		done
		if [ ! "${TARGET_NVME_DEVICE}" = "" ]; then
			break
		fi
	done;

	# Fallback to device names
	for DEVICE_NAME in ${TARGET_DEVICES[*]}
	do
		if [ -b "${DEVICE_NAME}" ] || [ -e "${DEVICE_NAME}" ]
		then
			TARGET_NVME_DEVICE=${DEVICE_NAME}
			printf "%s\n" "Warning: Falling back to device name"
			printf "%s\n" "Warning: Device names might change if instance is stopped or volumes are detached/added"
			break
		fi
	done

	if [ "${#TARGET_NVME_DEVICE}" -eq 0 ]; then
		printf "%s\n" "ERROR: unable to find the NVME device for ${TARGET_DEVICES}" 1>&2
		exit 2
	fi

	if [ -n "${VOLUME_GROUP}" ] && [ "${VOLUME_GROUP}" != "null" ]
	then
		if ! command -v lvm >/dev/null 2>&1 && [ -f /etc/redhat-release ]
		then
			sudo yum install lvm2 -y
		fi
		if ! command -v lvm >/dev/null 2>&1 && [ -f /etc/debian_version ]
		then
			export DEBIAN_FRONTEND="noninteractive"
			sudo apt-get install lvm2 -y
		fi
		# Check if volume exists to either create or extend volume group
		if sudo vgs ${VOLUME_GROUP} >/dev/null 2>&1
		then
			VG_CMD=vgextend
		else
			VG_CMD=vgcreate
		fi
		sudo pvcreate "${TARGET_NVME_DEVICE}"
		sudo "${VG_CMD}" "${VOLUME_GROUP}" "${TARGET_NVME_DEVICE}"
	else
		# Mount point and volume creation
		sudo "mkfs.${FSTYPE}" "${TARGET_NVME_DEVICE}"
		sudo mkdir -p "${MOUNT_POINT}"
		# Get device UUID with blkid as exported format:
		# UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
		printf "%s\n" "Warning: Will be mounted by UUID in /etc/fstab"
		UUID=$(sudo blkid ${TARGET_NVME_DEVICE} -o export | grep -E "^UUID=")
		printf "%s\n" "${UUID} ${MOUNT_POINT} ${FSTYPE} ${FSMOUNTOPT} 0 0" | sudo tee -a /etc/fstab
		sudo mount --all
	fi

done

# Create logical volumes
_jq_key "${VOLUME_GROUPS}" "keys[]" | \
while read -r VOLUME_GROUP
do
	# Get the value of the key
	VOLUME_DATA=$(_jq_key "${VOLUME_GROUPS}" ".\"${VOLUME_GROUP}\"")
	_jq_key "${VOLUME_DATA}" "keys[]" | \
	while read -r MOUNT_POINT
	do
		MOUNT_DATA=$(_jq_key "${VOLUME_DATA}" ".\"${MOUNT_POINT}\"")
		SIZE=$(_jq_key "${MOUNT_DATA}" '.size')
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
done
