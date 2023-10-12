#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

printf -v coredns_error "consolidate 5m '.* i/o timeout$' warning\n"

yq_add sc "k8s_cluster/ck8s-k8s-cluster" .coredns_additional_error_config "\"$coredns_error\""
yq_add wc "k8s_cluster/ck8s-k8s-cluster" .coredns_additional_error_config "\"$coredns_error\""
