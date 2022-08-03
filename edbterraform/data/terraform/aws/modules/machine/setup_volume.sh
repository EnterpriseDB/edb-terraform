#!/bin/bash
COUNTER=0
DEVICE=$1
MOUNTPOINT=$2

while [ ! -b ${DEVICE} ]; do
    sleep 2
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 10 ]; then
        exit 2
    fi
done


sudo mkfs.ext4 "${DEVICE}"
sudo mkdir -p "${MOUNTPOINT}"
echo "${DEVICE} ${MOUNTPOINT} ext4 noatime 0 0" | sudo tee -a /etc/fstab
sudo mount -t ext4 -o noatime ${DEVICE} ${MOUNTPOINT}
