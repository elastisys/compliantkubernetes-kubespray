#!/bin/bash

# This script takes care of initializing a CK8S configuration path for kubespray.
# It writes the default configuration files to the config path and generates
# some defaults where applicable.
# It's not to be executed on its own but rather via `ck8s-kubespray init <wc|sc>``.

set -eu -o pipefail
shopt -s globstar nullglob dotglob

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "error when running $0: argument mismatch" 1>&2
  exit 1
fi

flavor=$1
if [ $# -eq 2 ]; then
  fingerprint=$2
fi

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

# Validate the flavor
if [ "${flavor}" != "default" ] &&
  [ "${flavor}" != "gcp" ] &&
  [ "${flavor}" != "openstack" ] &&
  [ "${flavor}" != "vsphere" ] &&
  [ "${flavor}" != "upcloud" ] &&
  [ "${flavor}" != "aws" ]; then
  log_error "ERROR: Unsupported flavor: ${flavor}"
  exit 1
fi

generate_sops_config() {
  if [ -z ${fingerprint+x} ]; then
    if [ -z ${CK8S_PGP_FP+x} ]; then
      log_error "ERROR: either the <SOPS fingerprint> argument or the env variable CK8S_PGP_FP must be set."
      exit 1
    else
      fingerprint="${CK8S_PGP_FP}"
    fi
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

log_info "Initializing CK8S configuration with flavor: ${flavor}"
mkdir -p "${config_path}"

# Copy default group_vars
cp -r "${config_defaults_path}/common/group_vars" "${config_path}/"

cp -r --dereference "${config_defaults_path}/${flavor}/group_vars" "${config_path}/"

# Copy inventory.ini
if [[ ! -f "${config[inventory_file]}" ]]; then
  PREFIX=${prefix} envsubst >"${config[inventory_file]}" <"${config_defaults_path}/inventory.ini"
else
  log_info "Inventory already exists, leaving it as it is"
fi

log_info "Config initialized"

log_info "Time to edit the following files:"
log_info "${config[inventory_file]}"
