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

for item in ${SCRIPT_INPUTS}
do
	_jq_key() {
		printf %s "$1" | jq -rc "$2"
	}
	# Expected device paths: ["/dev/sdX","/dev/sdY"]
	TARGET_DEVICES=$(_jq_key "$item" '.device_names[]')

	# Mount point
	MOUNT_POINT=$(_jq_key "$item" '.mount_point')
	# Total number of nvme devices that should be present on the system
	N_NVME_DEVICE=$(_jq_key "$item" '.number_of_volumes')
	FSTYPE=$(_jq_key "$item" '.filesystem')
	FSMOUNTOPT=$(_jq_key "$item" '.mount_options')

	TARGET_NVME_DEVICE=""
	FSMOUNTOPT_ARG=""

	if [ ! "${FSMOUNTOPT}" = "" ]; then
		FSMOUNTOPT_ARG="-o ${FSMOUNTOPT}"
	fi

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
	for DEVICE_NAME in "${TARGET_DEVICES[@]}"; do
		if [[ -e ${DEVICE_NAME} ]]; then
			TARGET_NVME_DEVICE=${DEVICE_NAME}
			printf "%s\n" "Warning: Falling back to device name"
			printf "%s\n" "Warning: Device names might change if instance is stopped or volumes are detached/added"
			break
		fi
	done;

	if [ "${#TARGET_NVME_DEVICE}" -eq 0 ]; then
		printf "%s\n" "ERROR: unable to find the NVME device for ${TARGET_DEVICES}" 1>&2
		exit 2
	fi

	if [ "${FSTYPE}" = "lvm" ]; then
		if ! command -v lvm >/dev/null 2>&1 && [ -f /etc/redhat-release ]; then
			sudo yum install lvm2 -y
		fi
		if ! command -v lvm >/dev/null 2>&1 && [ -f /etc/debian_version ]; then
			export DEBIAN_FRONTEND="noninteractive"
			sudo apt-get install lvm2 -y
		fi
		sudo pvcreate "${TARGET_NVME_DEVICE}"
	else
		# Mount point and volume creation
		sudo "mkfs.${FSTYPE}" "${TARGET_NVME_DEVICE}"
		sudo mkdir -p "${MOUNT_POINT}"
		# Get device UUID with blkid as exported format:
		# UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
		printf "%s\n" "Warning: Will be mounted by UUID in /etc/fstab"
		UUID=$(sudo blkid ${TARGET_NVME_DEVICE} -o export | grep -E "^UUID=")
		printf "%s\n" "${UUID} ${MOUNT_POINT} ${FSTYPE} ${FSMOUNTOPT} 0 0" | sudo tee -a /etc/fstab
		eval "sudo mount -t ${FSTYPE} ${FSMOUNTOPT_ARG} ${TARGET_NVME_DEVICE} ${MOUNT_POINT}"
	fi

done
