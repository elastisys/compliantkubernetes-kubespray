#!/usr/bin/env bash

set -eu

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=migration/calico-to-cilium/common.sh
source "${here}/common.sh"

declare -a resources
resources=(
  "daemonset/cilium"
  "deployment/cilium-operator"
  "deployment/hubble-relay"
  "deployment/hubble-ui"
)

NS="kube-system"
for resource in "${resources[@]}"; do
  if kubectl -n "${NS}" get "${resource}" >/dev/null 2>&1; then
    log_info "Restaring $(yellow_text "${resource}") in the $(yellow_text "${NS}") namespace"
    kubectl -n "${NS}" rollout restart "${resource}"
    kubectl -n "${NS}" rollout status "${resource}" --watch
  fi
done
