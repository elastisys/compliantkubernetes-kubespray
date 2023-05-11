#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

yq_remove sc k8s_cluster/ck8s-k8s-cluster .kubelet_secure_addresses
yq_remove wc k8s_cluster/ck8s-k8s-cluster .kubelet_secure_addresses
