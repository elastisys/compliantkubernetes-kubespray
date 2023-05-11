#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

yq_add sc k8s_cluster/ck8s-k8s-cluster .kubelet_shutdown_grace_period "\"30s\""
yq_add sc k8s_cluster/ck8s-k8s-cluster .kubelet_shutdown_grace_period_critical_pods "\"10s\""

yq_add wc k8s_cluster/ck8s-k8s-cluster .kubelet_shutdown_grace_period "\"30s\""
yq_add wc k8s_cluster/ck8s-k8s-cluster .kubelet_shutdown_grace_period_critical_pods "\"10s\""
