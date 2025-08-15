#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" == "both" ]]; then
  clusters=("sc" "wc")
else
  clusters+=("${CK8S_CLUSTER}")
fi

src_file="${ROOT}/config/common/group_vars/all/ck8s-sysctl.yaml"

if [[ ! -f "${src_file}" ]]; then
  log_error "Source file not found: ${src_file}"
  exit 1
fi

for cluster in "${clusters[@]}"; do
  mapfile -t matches < <(grep -Rn "additional_sysctl" "${CK8S_CONFIG_PATH}/${cluster}-config/group_vars")

  if ((${#matches[@]} > 0)); then
    log_info "Existing settings found in ${CK8S_CONFIG_PATH}/${cluster}-config/group_vars, skipping"
  else
    log_info "Copying sysctl defaults for ${cluster}"
    dst_file="${CK8S_CONFIG_PATH}/${cluster}-config/group_vars/all/ck8s-sysctl.yaml"
    cp "${src_file}" "${dst_file}"
  fi
done
