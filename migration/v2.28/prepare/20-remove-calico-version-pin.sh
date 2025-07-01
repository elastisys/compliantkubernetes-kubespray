#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info "Removing calico_version pin to use Kubespray default (v3.29.x)"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  log_info "Removing calico_version from service cluster config"
  yq4 -i 'del(.calico_version)' "${CK8S_CONFIG_PATH}/sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml"
fi

if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  log_info "Removing calico_version from workload cluster config"
  yq4 -i 'del(.calico_version)' "${CK8S_CONFIG_PATH}/wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml"
fi

log_info "Calico will now use the default version from Kubespray (v3.29.1)"
log_info "This change requires compliantkubernetes-apps version v0.47+ that supports Calico v3.29.x"
