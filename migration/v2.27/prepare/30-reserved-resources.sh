#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

# Usage: update_reserved_resources <sc|wc>
function update_reserved_resources() {
  cluster="${1}"

  log_info "Updating reserved resources for ${cluster}"

  kubespray_config_path="${CK8S_CONFIG_PATH}/${cluster}-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml"

  yq4 -i '.kube_memory_reserved = "512Mi"' "${kubespray_config_path}"
  yq4 -i '.kube_cpu_reserved = "100m"' "${kubespray_config_path}"
  yq4 -i '.system_cpu_reserved = "0m"' "${kubespray_config_path}"
  yq4 -i '.system_memory_reserved = "0Mi"' "${kubespray_config_path}"
}

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  update_reserved_resources sc
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  update_reserved_resources wc
fi
