#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

for cluster in "sc" "wc"; do
  # Move the old config
  yq_move "${cluster}" "k8s_cluster/ck8s-k8s-cluster" ".kubelet_config_extra_args.imageGCHighThresholdPercent" ".kubelet_image_gc_high_threshold"
  yq_move "${cluster}" "k8s_cluster/ck8s-k8s-cluster" ".kubelet_config_extra_args.imageGCLowThresholdPercent" ".kubelet_image_gc_low_threshold"

  # If the object `kubelet_config_extra_args` is empty we can delete it
  if [[ "$(yq_length "${cluster}" "k8s_cluster/ck8s-k8s-cluster" ".kubelet_config_extra_args")" == "0" ]]; then
    yq_remove "${cluster}" "k8s_cluster/ck8s-k8s-cluster" ".kubelet_config_extra_args"
  fi
done
