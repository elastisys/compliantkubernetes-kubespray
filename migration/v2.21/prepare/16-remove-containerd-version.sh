#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

for CLUSTER in sc wc; do
  if ! yq_null "${CLUSTER}" k8s_cluster/ck8s-k8s-cluster .containerd_version; then
    if yq_check "${CLUSTER}" k8s_cluster/ck8s-k8s-cluster .containerd_version 1.6.12; then
      log_info "- remove containerd version 1.6.12 from ${CLUSTER}"
      yq_remove "${CLUSTER}" k8s_cluster/ck8s-k8s-cluster .containerd_version
      yq_remove "${CLUSTER}" k8s_cluster/ck8s-k8s-cluster .containerd_archive_checksums
    fi
  fi
done
