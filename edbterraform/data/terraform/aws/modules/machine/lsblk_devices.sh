#!/bin/bash
set -euo pipefail

SSH_CONNECTION="$1"
SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=240"
CMD="sudo lsblk -o NAME,KNAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,SERIAL,MODEL,VENDOR,REV,LABEL,UUID,PARTTYPE,PARTLABEL,PARTUUID,SCHED --json 2>&1"

RESULT=$(ssh $SSH_OPTIONS $SSH_CONNECTION $CMD)
RC=$?
if [[ $RC -ne 0 ]];
then
  printf "%s\n" "$RESULT" 1>&2
  exit $RC
fi

jq -n --arg base64json "$(printf %s $RESULT | base64 | tr -d \\n)" '{"base64json": $base64json}'
