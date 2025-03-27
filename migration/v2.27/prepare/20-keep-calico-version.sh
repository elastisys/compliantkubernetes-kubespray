#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  log_info "Setting calico version for service cluster"
  yq4 -i '.calico_version = "v3.27.4"' "${CK8S_CONFIG_PATH}/sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml"
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  log_info "Setting calico version for workload cluster"
  yq4 -i '.calico_version = "v3.27.4"' "${CK8S_CONFIG_PATH}/wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml"
fi
