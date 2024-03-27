#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  yq_add sc k8s_cluster/ck8s-k8s-cluster .kube_scheduler_profiles "load(\"${ROOT}/config/common/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml\").kube_scheduler_profiles"
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  yq_add wc k8s_cluster/ck8s-k8s-cluster .kube_scheduler_profiles "load(\"${ROOT}/config/common/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml\").kube_scheduler_profiles"
fi
