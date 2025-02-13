#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  if [[ -f "${CK8S_CONFIG_PATH}/sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster-upcloud.yaml" ]]; then
    tfvars_file="${CK8S_CONFIG_PATH}/sc-config/cluster.tfvars"
    if ! grep -P "^loadbalancer_legacy_network" "${tfvars_file}" >/dev/null; then
      echo "loadbalancer_legacy_network = true" >>"${tfvars_file}"
    fi
  else
    log_info "Not an UpCloud environment, skipping sc"
  fi
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  if [[ -f "${CK8S_CONFIG_PATH}/wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster-upcloud.yaml" ]]; then
    tfvars_file="${CK8S_CONFIG_PATH}/wc-config/cluster.tfvars"
    if ! grep -P "^loadbalancer_legacy_network" "${tfvars_file}" >/dev/null; then
      echo "loadbalancer_legacy_network = true" >>"${tfvars_file}"
    fi
  else
    log_info "Not an UpCloud environment, skipping wc"
  fi
fi
