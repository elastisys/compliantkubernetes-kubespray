#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

cilium_path="group_vars/k8s_cluster/ck8s-cilium.yaml"

src_file="${ROOT}/config/common/${cilium_path}"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  dest_file="${CK8S_CONFIG_PATH}/sc-config/${cilium_path}"
  if [[ ! -f "${dest_file}" ]]; then
    log_info "Copying ck8s-cilium config to SC [src=${src_file} dest=${dest_file}]"
    cp "${src_file}" "${dest_file}"
  fi
fi

if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  dest_file="${CK8S_CONFIG_PATH}/wc-config/${cilium_path}"
  if [[ ! -f "${dest_file}" ]]; then
    log_info "Copying ck8s-cilium config to WC [src=${src_file} dest=${dest_file}]"
    cp "${src_file}" "${dest_file}"
  fi
fi
