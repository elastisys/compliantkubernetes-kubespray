#!/bin/bash

set -e -o pipefail

here="$(dirname "$(readlink -f "$0")")"

if [[ "$#" -lt 1 || "$#" -gt 3 ]]; then
  echo "${0} <host ip> [sdb] [ssh-user]"
  exit 1
fi

SSH_USER="${3:-}"
if [[ -z "$SSH_USER" ]]; then
  SSH_USER="ubuntu"
  echo "INFO: no SSH user provided, will use \"${SSH_USER}\""
fi

HOST_IP=${1}
#Check that it is a valid IP
if [[ ! (${HOST_IP} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$) ]]; then
  echo "ERROR: host ip ${HOST_IP} is not a IP address."
  exit 1
fi

#Set disk
if [[ "$#" -eq 1 ]]; then
  echo -n "Enter disk to wipe (Continue for default: sdb):"
  read -r disk
  if [ -z "${disk}" ]; then
    DISK=sdb
  else
    DISK="${disk}"
  fi
  echo ""
else
  DISK=${2}
fi

echo "WARNING!"
echo "This script will wipe the disk /dev/${DISK} on machine ${HOST_IP}"
echo -n "Are you sure you want to continue (y/N): "
read -r reply
if [[ ${reply} != "y" ]]; then
  echo "Exited"
  exit 1
fi

echo "Staring to wipe disk"
ssh "${SSH_USER}@${HOST_IP}" DISK="/dev/${DISK}" 'bash -s' <"${here}/zap-disk"
