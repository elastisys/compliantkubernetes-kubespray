#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

CLUSTERS=("sc" "wc")
if [[ "${CK8S_CLUSTER}" != both ]]; then
  CLUSTERS=("${CK8S_CLUSTER}")
fi

for cluster in "${CLUSTERS[@]}"; do
  #Enabling Typha and Typha metrics
  yq_add ${cluster} k8s_cluster/ck8s-k8s-cluster .typha_enabled "load(\"${ROOT}/config/common/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml\").typha_enabled"
  yq_add ${cluster} k8s_cluster/ck8s-k8s-cluster .typha_prometheusmetricsenabled "load(\"${ROOT}/config/common/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml\").typha_prometheusmetricsenabled"
done
