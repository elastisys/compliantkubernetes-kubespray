#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

yq_add sc k8s_cluster/ck8s-k8s-cluster .podsecuritypolicy_enabled false
yq_remove sc k8s_cluster/ck8s-k8s-cluster '.kube_apiserver_enable_admission_plugins[] | select(. == "PodSecurityPolicy")'

yq_add wc k8s_cluster/ck8s-k8s-cluster .podsecuritypolicy_enabled false
yq_remove wc k8s_cluster/ck8s-k8s-cluster '.kube_apiserver_enable_admission_plugins[] | select(. == "PodSecurityPolicy")'

if [[ -f "${CK8S_CONFIG_PATH}/rook/operator-values.yaml" ]]; then
    log_info "  - add: false to .pspEnable"
    yq4 -i ".pspEnable = false" "$CK8S_CONFIG_PATH/rook/operator-values.yaml"
fi
