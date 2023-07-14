#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

for CLUSTER in sc wc; do
  if ! yq_null "${CLUSTER}" k8s_cluster/ck8s-k8s-cluster .containerd_max_container_log_line_size; then
    if yq4 '.containerd_max_container_log_line_size | test("unprivileged")' "${CK8S_CONFIG_PATH}/${CLUSTER}-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml"; then
      log_info "- enable unprivileged ports and icmp in ${CLUSTER}"
      yq_add "${CLUSTER}" k8s_cluster/ck8s-k8s-cluster .containerd_enable_unprivileged_ports true
      yq_add "${CLUSTER}" k8s_cluster/ck8s-k8s-cluster .containerd_enable_unprivileged_icmp true

      log_info "- remove the old containerd_max_container_log_line_size from ${CLUSTER}"
      yq_remove "${CLUSTER}" k8s_cluster/ck8s-k8s-cluster .containerd_max_container_log_line_size
    fi
  fi
done
