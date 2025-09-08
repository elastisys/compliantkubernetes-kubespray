#!/usr/bin/env bash

set -eu

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=migration/calico-to-cilium/common.sh
source "${here}/common.sh"

CONFIG_DIR="${CK8S_CONFIG_PATH}/${TARGET_CLUSTER}-config/group_vars/k8s_cluster"

patch_yaml_config() {
  local -r patch_file="${1}"
  local -r config_file="${2}"

  log_info "Patching $(yellow_text "${CONFIG_DIR}/${config_file}") with $(yellow_text "${here}/${patch_file}")"

  # shellcheck disable=SC2016
  yq eval-all '. as $item ireduce ({}; . * $item)' "${here}/${patch_file}" "${CONFIG_DIR}/${config_file}" >"${CONFIG_DIR}/${config_file}.new"
  mv -f "${CONFIG_DIR}/${config_file}.new" "${CONFIG_DIR}/${config_file}"
}

enable_monitoring() {
  local -r config="${CONFIG_DIR}/ck8s-cilium.yaml"

  log_info "Enabling service monitors for Cilium"

  yq -i '.ck8s_cilium.operator.monitoring.installServiceMonitor = true' "${config}"
  yq -i '.ck8s_cilium.hubble.monitoring.installServiceMonitor = true' "${config}"
  yq -i '.ck8s_cilium.prometheus.installServiceMonitor = true' "${config}"
}

patch_yaml_config config/enable-cilium.yaml ck8s-k8s-cluster.yaml
if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null; then
  enable_monitoring
fi
