#!/usr/bin/env bash

set -eu

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=migration/calico-to-cilium/common.sh
source "${here}/common.sh"

check_bin kubectl
check_bin cilium-cli
check_bin kubectl-evict

NODE="${1:-}"
if [[ -z "${NODE}" ]]; then
  log_error "FATAL: need a node name" >&2
  exit 1
fi
NODE_HASH="$(echo -n "${NODE}" | md5sum | awk '{print $1}')"

log_info "Starging migration for node $(yellow_text "${NODE}") with hash $(yellow_text "${NODE_HASH}")"

# Mark the node to allow cilium per-node configuration + skip from tainting
label_node "${NODE}" "cilium-default"
label_node "${NODE}" "skip-taint"

deferred_unlabel() {
  # Remove the 'skip-taint' label
  unlabel_node "${NODE}" "skip-taint"
}
trap deferred_unlabel EXIT INT TERM

# Cycle the cilium pod of the node to trigger CNI re-configuration
log_info "Cycling cilium pod on $(yellow_text "${NODE}")"
kubectl -n kube-system delete pod --field-selector spec.nodeName="${NODE}" -l k8s-app=cilium
kubectl -n kube-system rollout status daemonset/cilium --watch

# Check the node connectivity
if ! check_node_connectivity "${NODE}" "${NODE_HASH}"; then
  log_error "FATAL: could not confirm network connectivity for node ${NODE}"
  exit 1
fi

# Add a temporary taint to all OTHER nodes (prevents scheduling elsewhere)
log_info "Tainting all nodes not labeled with $(yellow_text "${LABEL_PREFIX}/skip-taint")"
taint_nodes "cilium-guard-${NODE_HASH}" "$(get_unlabeled_nodes "skip-taint")"

deferred_untaint() {
  # Remove the temporary taints from other nodes
  log_info "Removing temporary taint from all nodes"
  untaint_nodes "cilium-guard-${NODE_HASH}" "$(get_all_nodes)"
}
trap deferred_untaint EXIT INT TERM

# Evict node pods managed by Calico one by one, with retries, thus respecting PDBs
# -> since we tainted every other node, they should be scheduling on the node we're processing
get_node_pods_with_ip_prefix "${NODE}" "${CALICO_IP_PREFIX}" | xargs "${here}/evict_queue.py"
