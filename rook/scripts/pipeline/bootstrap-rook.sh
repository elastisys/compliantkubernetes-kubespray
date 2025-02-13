#!/bin/bash

# This script is only meant for running in the pipeline

if [[ -z "$CK8S_APPS_PIPELINE" ]]; then
  exit 1
fi

here="$(dirname "$(readlink -f "$0")")"
if [[ "$CLUSTER" = "sc" ]]; then
  IPADDRESSES=()
  export TFSTATE_FILE="${CK8S_CONFIG_PATH}/pipeline-sc-config/terraform.tfstate"
  read -r -a IPADDRESSES <<<"$(jq -r '[.outputs.worker_ips.value | to_entries | .[] | select(.key | test("worker")) | .value.public_ip] | @sh' "$TFSTATE_FILE" | sed -e "s/'//g")"
  for IP in "${IPADDRESSES[@]}"; do
    "${here}"/zap-disk-auto.sh "${IP}" vda2
  done
  helmfile -e service -l stage=bootstrap apply &>/dev/null
elif [[ "$CLUSTER" = "wc" ]]; then
  IPADDRESSES=()
  export TFSTATE_FILE="${CK8S_CONFIG_PATH}/pipeline-wc-config/terraform.tfstate"
  read -r -a IPADDRESSES <<<"$(jq -r '[.outputs.worker_ips.value | to_entries | .[] | select(.key | test("worker")) | .value.public_ip] | @sh' "$TFSTATE_FILE" | sed -e "s/'//g")"
  for IP in "${IPADDRESSES[@]}"; do
    "${here}"/zap-disk-auto.sh "${IP}" vda2
  done
  helmfile -e workload -l stage=bootstrap apply &>/dev/null
fi
