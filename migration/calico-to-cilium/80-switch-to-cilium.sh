#!/usr/bin/env bash

set -eu

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=migration/calico-to-cilium/common.sh
source "${here}/common.sh"

CONFIG_DIR="${CK8S_CONFIG_PATH}/${TARGET_CLUSTER}-config/group_vars/k8s_cluster"

patch_yaml_config() {
  local -r config_file="${CONFIG_DIR}/ck8s-k8s-cluster.yaml"

  log_info "Switching Calico to Cilium in $(yellow_text "ck8s-k8s-cluster.yaml")"

  yq -i '.kube_network_plugin = "cilium"' "${config_file}"
  yq -i '.cilium_version = "1.17.5"' "${config_file}"
  yq -i '.cilium_identity_allocation_mode = "crd"' "${config_file}"
  yq -i '.cilium_enable_hubble = true' "${config_file}"
  yq -i '.cilium_hubble_install = true' "${config_file}"
  yq -i '.cilium_hubble_tls_generate = true' "${config_file}"
  yq -i '.cilium_pool_cidr = "10.235.64.0/18"' "${config_file}"
  yq -i '.kube_owner = "root"' "${config_file}"
}

enable_monitoring() {
  local -r config="${CONFIG_DIR}/ck8s-cilium.yaml"

  log_info "Enabling service monitors for Cilium"

  yq -i '.ck8s_cilium.operator.monitoring.installServiceMonitor = true' "${config}"
  yq -i '.ck8s_cilium.hubble.monitoring.installServiceMonitor = true' "${config}"
  yq -i '.ck8s_cilium.prometheus.installServiceMonitor = true' "${config}"
}

patch_yaml_config
if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null; then
  enable_monitoring
fi
