#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info "disable openstack lbaas if infra provider is safespring"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  log_info "Replacing openstack_lbaas_enabled with external_openstack_lbaas_enabled in service cluster config"

  CONFIG_FILE="${CK8S_CONFIG_PATH}/sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster-openstack.yaml"

  # Check if the key exists and equals false
  if yq4 '.openstack_lbaas_enabled' "$CONFIG_FILE" | grep -q '^false$'; then
    # Delete old key
    yq4 -i 'del(.openstack_lbaas_enabled)' "$CONFIG_FILE"
    # Add new key with same value
    yq4 -i '.external_openstack_lbaas_enabled = false' "$CONFIG_FILE"
  fi
fi

if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  log_info "Replacing openstack_lbaas_enabled with external_openstack_lbaas_enabled in workload cluster config"

  CONFIG_FILE="${CK8S_CONFIG_PATH}/wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster-openstack.yaml"

  # Check if the key exists and equals false
  if yq4 '.openstack_lbaas_enabled' "$CONFIG_FILE" | grep -q '^false$'; then
    # Delete old key
    yq4 -i 'del(.openstack_lbaas_enabled)' "$CONFIG_FILE"
    # Add new key with same value
    yq4 -i '.external_openstack_lbaas_enabled = false' "$CONFIG_FILE"
  fi
fi

