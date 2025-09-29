#!/usr/bin/env bash

export CALICO_IP_PREFIX="10.233"
export CILIUM_IP_PREFIX="10.235"

export LABEL_PREFIX="io.cilium.migration"

red_text() {
  echo -e "\e[31m${*}\e[0m"
}

yellow_text() {
  echo -e "\e[93m${*}\e[0m"
}

blue_text() {
  echo -e "\e[34m${*}\e[0m"
}

log_info() {
  echo -e "\n[$(blue_text calico-to-cilium)] ${*}" 1>&2
}

log_error() {
  echo -e "[$(red_text calico-to-cilium)] ${*}" 1>&2
}

# Usage: check_bin <binary_basename>
check_bin() {
  command -v "${1}" >/dev/null || {
    log_error "FATAL: ${1} not found; Ensure you have it installed and within PATH" >&2
    exit 1
  }
}

# Usage: hash_node <node_name>
hash_node() {
  local -r node="${1}"
  echo -n "${node}" | md5sum | awk '{print $1}'
}

# Usage: label_node <node_name> <sub_label>
# -> will use LABEL_PREFIX to namespace labels
label_node() {
  local -r node="${1}"
  local -r label="${LABEL_PREFIX}/${2}=true"

  log_info "Labeling $(yellow_text "${node}") with $(yellow_text "${label}")"
  kubectl label node "${node}" --overwrite "${label}"
}

# Usage: unlabel_node <node_name> <sub_label>
# -> will use LABEL_PREFIX to namespace labels
unlabel_node() {
  local -r node="${1}"
  local -r label="${LABEL_PREFIX}/${2}"

  log_info "Removing the $(yellow_text "${label}") label from $(yellow_text "${node}")"
  kubectl label node "${node}" "${label}-"
}

# Usage: taint_nodes <taint_name> [<node_name> ...]
taint_nodes() {
  local -r taint="${1}"
  shift
  local -a node_arr
  read -r -a node_arr <<<"${*}"

  if [ ${#node_arr[@]} -gt 0 ]; then
    kubectl taint nodes "${node_arr[@]}" --overwrite "${taint}=true:NoSchedule"
  fi
}

# Usage: untaint_nodes <taint_name> [<node_name> ...]
untaint_nodes() {
  local -r taint="${1}"
  shift
  local -a node_arr
  read -r -a node_arr <<<"${*}"

  if [ ${#node_arr[@]} -gt 0 ]; then
    kubectl taint nodes "${node_arr[@]}" --overwrite "${taint}=true:NoSchedule-" || true
  fi
}

# Usage: get_all_nodes
get_all_nodes() {
  kubectl get nodes -o jsonpath='{.items[*].metadata.name}'
}

# Usage: get_unlabeled_pods <sub_label>
# -> returns all nodes that are NOT labeled with "${LABEL_PREFIX}/<sub_label>"
get_unlabeled_nodes() {
  local -r sub_label="${1}"
  kubectl get nodes -o json |
    jq -r '
      .items[] |
      select(.metadata.labels."'"${LABEL_PREFIX}/${sub_label}"'" == null) |
      .metadata.name' |
    tr '\n' ' '
}

# Usage: check_node_connectivity <node_name> <node_hash>
check_node_connectivity() {
  local -r node="${1}"
  local -r node_hash="${2:-$(hash_node "${node}")}"
  cilium-cli status --wait --interactive=false

  kubectl get -o wide node "${node}"

  local attempt attempt_txt
  for attempt in $(seq 1 60); do
    attempt_txt=""
    if [ "$attempt" -gt 1 ]; then
      attempt_txt=" [attempt #${attempt}/60]"
    fi
    log_info "Checking status of node $(yellow_text "${node}")${attempt_txt}"

    # shellcheck disable=SC2016
    if kubectl --namespace kube-system run --attach --rm --restart=Never "verify-network-${node_hash}" \
      --overrides='{"spec": {"nodeName": "'"${node}"'", "tolerations": [{"operator": "Exists"}]}}' \
      --image ghcr.io/nicolaka/netshoot:v0.14 -- /bin/bash -c 'ip -br addr && curl -s -k https://$KUBERNETES_SERVICE_HOST/healthz && echo' | grep "$CILIUM_IP_PREFIX"; then
      return 0
    fi

    sleep 5
  done

  return 1
}

# Usage: get_node_pods_with_ip_prefix <node_name> <ip_prefix>
# -> returns /-separated tuples of (pod_namespace, pod_name), one per line
get_node_pods_with_ip_prefix() {
  local -r node="${1}"
  local -r ip_prefix="${2}"

  kubectl get pods --all-namespaces --field-selector spec.nodeName="${node}" -o json |
    jq -r --arg ip_test "^${ip_prefix}" '
      .items[] |
      select(.status.phase == "Running" or .status.phase == "Pending") |
      select(.status.podIP | test($ip_test)) |
      "\(.metadata.namespace)/\(.metadata.name)"'
}

# Make this script executable
(return 0 2>/dev/null) && sourced=1 || sourced=0

if [[ "$sourced" == "0" ]] && [[ -n "${1:-}" ]]; then
  cmd="${1}"
  shift
  "${cmd}" "${@}"
fi
