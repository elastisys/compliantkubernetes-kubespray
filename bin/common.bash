#!/bin/bash

# This file is not supposed to be executed on it's own, but rather is sourced
# by the other scripts in this path. It holds common paths and functions that
# are used throughout all of the scripts.

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
: "${prefix:?Missing prefix}"

# Create CK8S_CONFIG_PATH if it does not exist and make it absolute
mkdir -p "${CK8S_CONFIG_PATH}"
CK8S_CONFIG_PATH=$(readlink -f "${CK8S_CONFIG_PATH}")
export CK8S_CONFIG_PATH

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
root_path="${here}/.."
# shellcheck disable=SC2034
config_defaults_path="${root_path}/config"
# shellcheck disable=SC2034
kubespray_path="${root_path}/kubespray"

config_path="${CK8S_CONFIG_PATH}/${prefix}-config"
ssh_folder="${config_path}/ssh"
sops_config="${CK8S_CONFIG_PATH}/.sops.yaml"

declare -A config
# shellcheck disable=SC2034
config["inventory_file"]="${config_path}/inventory.ini"

declare -A secrets
# shellcheck disable=SC2034
secrets["ssh_key"]="${ssh_folder}/id_rsa"

log_info() {
    echo -e "[\e[34mck8s\e[0m] ${*}" 1>&2
}

log_warning() {
    echo -e "[\e[33mck8s\e[0m] ${*}" 1>&2
}

log_error() {
    echo -e "[\e[31mck8s\e[0m] ${*}" 1>&2
}

validate_sops_config() {
    if [ ! -f "${sops_config}" ]; then
        log_error "ERROR: SOPS config not found: ${sops_config}"
        exit 1
    fi

    rule_count=$(yq r - --length creation_rules < "${sops_config}")
    if [ "${rule_count:-0}" -gt 1 ]; then
        log_error "ERROR: SOPS config has more than one creation rule."
        exit 1
    fi

    fingerprints=$(yq r - 'creation_rules[0].pgp' < "${sops_config}")
    if ! [[ "${fingerprints}" =~ ^[A-Z0-9,' ']+$ ]]; then
        log_error "ERROR: SOPS config contains no or invalid PGP keys."
        log_error "fingerprints=${fingerprints}"
        log_error "Fingerprints must be uppercase and separated by colon."
        log_error "Delete or edit the SOPS config to fix the issue"
        log_error "SOPS config: ${sops_config}"
        exit 1
    fi
}

# Normally a signal handler can only run one command. Use this to be able to
# add multiple traps for a single signal.
append_trap() {
    cmd="${1}"
    signal="${2}"

    if [ "$(trap -p "${signal}")" = "" ]; then
        # shellcheck disable=SC2064
        trap "${cmd}" "${signal}"
        return
    fi

    previous_trap_cmd() { printf '%s\n' "$3"; }

    new_trap() {
        eval "previous_trap_cmd $(trap -p "${signal}")"
        printf '%s\n' "${cmd}"
    }

    # shellcheck disable=SC2064
    trap "$(new_trap)" "${signal}"
}

# Write PGP fingerprints to SOPS config
sops_config_write_fingerprints() {
    yq n 'creation_rules[0].pgp' "${1}" > "${sops_config}" || \
      (log_error "Failed to write fingerprints" && rm "${sops_config}" && exit 1)
}

# Encrypt a file in place.
sops_encrypt() {
    # https://github.com/mozilla/sops/issues/460
    if grep -F -q 'sops:' "${1}" || \
        grep -F -q '"sops":' "${1}" || \
        grep -F -q '[sops]' "${1}" || \
        grep -F -q 'sops_version=' "${1}"; then
        log_info "Already encrypted ${1}"
        return
    fi

    log_info "Encrypting ${1}"

    sops --config "${sops_config}" -e -i "${1}"
}

# Check that a file exists and is actually encrypted using SOPS.
sops_decrypt_verify() {
    if [ ! -f "${1}" ]; then
        log_error "ERROR: Encrypted file not found: ${1}"
        exit 1
    fi

    # https://github.com/mozilla/sops/issues/460
    if ! grep -F -q 'sops:' "${1}" && \
       ! grep -F -q '"sops":' "${1}" && \
       ! grep -F -q '[sops]' "${1}" && \
       ! grep -F -q 'sops_version=' "${1}"; then
        log_error "NOT ENCRYPTED: ${1}"
        exit 1
    fi
}

# Decrypt a file in place and encrypt it again at exit.
#
# Run this inside a sub-shell to encrypt the file again as soon as it's no
# longer used. For example:
# (
#   sops_decrypt config
#   command --config config
# )
# TODO: This is bad since it makes the decrypted secrets touch the filesystem.
#       We should try to remove this asap.
sops_decrypt() {
    log_info "Decrypting ${1}"

    sops_decrypt_verify "${1}"

    sops --config "${sops_config}" -d -i "${1}"
    append_trap "sops_encrypt ${1}" EXIT
}

# Temporarily decrypts a file and runs a command that can read it once.
sops_exec_file() {
    sops_decrypt_verify "${1}"

    sops --config "${sops_config}" exec-file "${1}" "${2}"
}

# The same as sops_exec_file except the decrypted file is written as a normal
# file on disk while it's being used.
# This should only be used if absolutely necessary, for example where the
# decrypted file needs to be read more than once.
# TODO: Try to eliminate this in the future.
sops_exec_file_no_fifo() {
    sops_decrypt_verify "${1}"

    sops --config "${sops_config}" exec-file --no-fifo "${1}" "${2}"
}
