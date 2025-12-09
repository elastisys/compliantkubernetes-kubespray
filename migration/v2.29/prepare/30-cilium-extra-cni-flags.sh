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
  #Add extra cni flags
  yq_add "${cluster}" k8s_cluster/ck8s-cilium .ck8s_cilium "load(\"${ROOT}/config/common/group_vars/k8s_cluster/ck8s-cilium.yaml\").ck8s_cilium"
done
