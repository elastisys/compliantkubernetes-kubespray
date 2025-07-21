#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

CALICO_VERSION='"3.27.4"'

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  log_info "Setting calico version for service cluster"
  yq_add sc k8s_cluster/ck8s-k8s-cluster .calico_version "${CALICO_VERSION}"
fi

if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  log_info "Setting calico version for workload cluster"
  yq_add wc k8s_cluster/ck8s-k8s-cluster .calico_version "${CALICO_VERSION}"
fi
