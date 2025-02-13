#!/usr/bin/env bash

# Ensures control plane nodes have taint "node-role.kubernetes.io/control-plane:NoSchedule"
# and removes old "node-role.kubernetes.io/master:NoSchedule" taint.

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

CK8S_CLUSTER="${1}"
export CK8S_CLUSTER

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

# functions currently available in the library:
#   - logging:
#     - log_info(_no_newline) <message>
#     - log_warn(_no_newline) <message>
#     - log_error(_no_newline) <message>
#     - log_fatal <message> # this will call "exit 1"
#
#  - yq:
#     - yq_null <sc|wc> <file> <target>
#     - yq_copy <sc|wc> <file> <source> <destination>
#     - yq_move <sc|wc> <file> <source> <destination>
#     - yq_remove <sc|wc> <file> <target>
#     - yq_length <sc|wc> <file> <target>

function get_cp_nodes() {
  kubectl get no -l node-role.kubernetes.io/control-plane -oyaml | yq4 ".items[].metadata.name"
}

function add_control_plane_taint() {
  local cp_nodes=()
  mapfile -t cp_nodes < <(get_cp_nodes)

  for node in "${cp_nodes[@]}"; do
    log_info "Adding taint \"node-role.kubernetes.io/control-plane:NoSchedule\" from node \"${node}\""
    kubectl taint no "${node}" node-role.kubernetes.io/control-plane:NoSchedule --overwrite
  done
}

function remove_master_taint() {
  local cp_nodes=()
  mapfile -t cp_nodes < <(get_cp_nodes)

  for node in "${cp_nodes[@]}"; do
    log_info "Removing taint \"node-role.kubernetes.io/master:NoSchedule\" from node \"${node}\""
    kubectl taint no "${node}" node-role.kubernetes.io/master- || true
  done
}

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  log_info "operation on service cluster"

  KUBECONFIG="${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml"
  export KUBECONFIG

  add_control_plane_taint
  remove_master_taint
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  log_info "operation on workload cluster"

  KUBECONFIG="${CK8S_CONFIG_PATH}/.state/kube_config_wc.yaml"
  export KUBECONFIG

  add_control_plane_taint
  remove_master_taint
fi

log_info "Done"
