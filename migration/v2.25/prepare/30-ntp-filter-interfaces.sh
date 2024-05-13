#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  yq_add sc k8s_cluster/ck8s-k8s-cluster .ntp_filter_interface "load(\"${ROOT}/config/common/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml\").ntp_filter_interface"
  yq_add sc k8s_cluster/ck8s-k8s-cluster .ntp_interfaces "load(\"${ROOT}/config/common/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml\").ntp_interfaces"
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  yq_add wc k8s_cluster/ck8s-k8s-cluster .ntp_filter_interface "load(\"${ROOT}/config/common/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml\").ntp_filter_interface"
  yq_add wc k8s_cluster/ck8s-k8s-cluster .ntp_interfaces "load(\"${ROOT}/config/common/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml\").ntp_interfaces"
fi
