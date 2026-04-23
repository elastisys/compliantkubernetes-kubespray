#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

# When applicable, apply SC/MC changes before WC to catch errors early
if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  cp "${ROOT}/config/common/group_vars/all/ck8s-image-tags.yaml" "${CK8S_CONFIG_PATH}/sc-config/group_vars/all/"
  cp "${ROOT}/config/common/group_vars/all/ck8s-kubeadm-patches.yaml" "${CK8S_CONFIG_PATH}/sc-config/group_vars/all/"
  cp "${ROOT}/config/ck8s-kube-proxy-image" "${CK8S_CONFIG_PATH}/sc-config/"
  yq_add sc all/ck8s-kubespray-general .ck8sKubesprayVersion "\"$(git_version)\""
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  cp "${ROOT}/config/common/group_vars/all/ck8s-image-tags.yaml" "${CK8S_CONFIG_PATH}/wc-config/group_vars/all/"
  cp "${ROOT}/config/common/group_vars/all/ck8s-kubeadm-patches.yaml" "${CK8S_CONFIG_PATH}/wc-config/group_vars/all/"
  cp "${ROOT}/config/ck8s-kube-proxy-image" "${CK8S_CONFIG_PATH}/wc-config/"
  yq_add wc all/ck8s-kubespray-general .ck8sKubesprayVersion "\"$(git_version)\""
fi
