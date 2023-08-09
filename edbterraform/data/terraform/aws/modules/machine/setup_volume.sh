#!/bin/bash

# Expected EBS device paths: "/dev/sdX,/dev/sdY"
IFS=',' read -r -a TARGET_EBS_DEVICES <<< $1

# Mount point
MOUNT_POINT=$2
# Total number of nvme devices that should be present on the system
N_NVME_DEVICE=$3
FSTYPE=$4

TARGET_NVME_DEVICE=""

# Install nvme-cli
if [ -f /etc/redhat-release ]; then
	sudo yum install nvme-cli -y
fi
if [ -f /etc/debian_version ]; then
	sudo apt update -y
	sudo apt install nvme-cli -y
fi

# Wait for the availability of all the NVME devices that should be
# present on the system.
while [ $(sudo nvme list | tail -n +3 | wc -l) -ne ${N_NVME_DEVICE} ]; do
	sleep 2
	COUNTER=$((COUNTER + 1))
	if [ $COUNTER -ge 10 ]; then
		echo "ERROR: unable to get the full list of NVME devices after 20s"
		break
	fi
done

# Based on the target EBS device (/dev/sdX) we have to find the corresponding
# NVME device.
for NVME_DEVICE in $(sudo ls /dev/nvme*n*); do
	EBS_DEVICE=$(sudo nvme id-ctrl -v ${NVME_DEVICE} | grep "0000:" | awk '{ print $18 }' | sed 's/["\.]//g')

	# /dev/ might be dropped at times so we need to check both cases
    if [ "$EBS_DEVICE" = "${TARGET_EBS_DEVICES[0]}" ] || [ "/dev/$EBS_DEVICE" = "${TARGET_EBS_DEVICES[0]}" ]; then
		TARGET_NVME_DEVICE=${NVME_DEVICE}
		break
	fi
done;

# Fallback to device names
for DEVICE_NAME in "${TARGET_EBS_DEVICES[@]}"; do
	if [[ -e ${DEVICE_NAME} ]]; then
		TARGET_NVME_DEVICE=${DEVICE_NAME}
		echo "Warning: Falling back to device name"
		echo "Warning: Device names might change if instance is stopped or volumes are detached/added"
		break
	fi
done;

if [ "${#TARGET_NVME_DEVICE}" -eq 0 ]; then
	echo "ERROR: unable to find the NVME device for ${TARGET_EBS_DEVICES}"
	exit 2
fi

# Mount point and volume creation
sudo "mkfs.${FSTYPE}" "${TARGET_NVME_DEVICE}"
sudo mkdir -p "${MOUNT_POINT}"
# Get device UUID with blkid as exported format:
# UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
echo "Warning: Will be mounted by UUID in /etc/fstab"
UUID=$(sudo blkid ${TARGET_NVME_DEVICE} -o export | grep -E "^UUID=")
echo "${UUID} ${MOUNT_POINT} ${FSTYPE} noatime 0 0" | sudo tee -a /etc/fstab
sudo mount -t "${FSTYPE}" -o noatime "${TARGET_NVME_DEVICE}" "${MOUNT_POINT}"
