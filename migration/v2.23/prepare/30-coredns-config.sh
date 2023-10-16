#!/usr/bin/env bash

set -e

additional_error_config='consolidate 5m ".* i/o timeout$" warning'

tempfile=$(mktemp)
trap 'rm -f "$tempfile"' EXIT

printf "coredns_additional_error_config: |\n  %s\n" "$additional_error_config" > "$tempfile"

yq4 eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$CK8S_CONFIG_PATH"/wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml "$tempfile" -i
yq4 eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$CK8S_CONFIG_PATH"/sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml "$tempfile" -i

rm -f "$tempfile"
