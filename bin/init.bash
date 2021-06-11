#!/bin/bash

# This script takes care of initializing a CK8S configuration path for kubespray.
# It writes the default configuration files to the config path and generates
# some defaults where applicable.
# It's not to be executed on its own but rather via `ck8s-kubespray init ...`.

set -eu -o pipefail
shopt -s globstar nullglob dotglob

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

cloud_provider="${CK8S_CLOUD_PROVIDER:-}"
fingerprint="${CK8S_PGP_FP:-}"

while [ "${#}" -gt 1 ]; do
    case "${1}" in
    "--cloud-provider") cloud_provider="${2}" ;;
    "--sops-fingerprint") fingerprint="${2}" ;;
    *)
        log_error "ERROR: unknown flag ${1}"
        exit 1
        ;;
    esac
    shift 2
done

if [ -z "${cloud_provider}" ]; then
    log_error "ERROR: either --cloud-provider or the environment variable CK8S_CLOUD_PROVIDER must be set."
    exit 1
fi

config_type="default"
if [ -n "${cloud_provider:-}" ]; then
    case "${cloud_provider:-}" in
        aws|gcp|vsphere)
            config_type="${cloud_provider}"
            ;;

        citycloud|safespring)
            config_type="openstack"
            ;;

        *)
            log_error "ERROR: Unsupported cloud provider: ${cloud_provider}"
            exit 1
            ;;
    esac
fi

generate_sops_config() {
    if [ -z "${fingerprint}" ]; then
        log_error "ERROR: either --sops-fingerprint or the environment variable CK8S_PGP_FP must be set."
        exit 1
    fi
    log_info "Initializing SOPS config with PGP fingerprint: ${fingerprint}"
    sops_config_write_fingerprints "${fingerprint}"
}

if [ -f "${sops_config}" ]; then
    log_info "SOPS config already exists: ${sops_config}"
    validate_sops_config
else
    generate_sops_config
fi

log_info "Initializing CK8S configuration with configuration type: ${config_type}"

mkdir -p "${config_path}"

# Copy common group_vars
cp -r "${config_defaults_path}/common/group_vars" "${config_path}/"

# Copy config type specific group_vars
cp -r "${config_defaults_path}/${config_type}/group_vars" "${config_path}/"

# Copy inventory.ini
if [[ ! -f "${config[inventory_file]}" ]]; then
  PREFIX=${prefix} envsubst > "${config[inventory_file]}" < "${config_defaults_path}/inventory.ini"
else
  log_info "Inventory already exists, leaving it as it is"
fi

log_info "Config initialized"

log_info "Time to edit the following files:"
log_info "${config[inventory_file]}"
