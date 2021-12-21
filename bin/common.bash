#!/bin/bash

# This file is not supposed to be executed on it's own, but rather is sourced
# by the other scripts in this path. It holds common paths and functions that
# are used throughout all of the scripts.

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
: "${prefix:?Missing prefix}"

# Check for this mistake https://github.com/koalaman/shellcheck/wiki/SC2088
# shellcheck disable=SC2088
if [[ "${CK8S_CONFIG_PATH:0:2}" == "~/" ]]; then
    echo "Warning: CK8S_CONFIG_PATH starts with unexpanded ~/" 1>&2
    echo "This will create a new folder in cwd called ~ instead of referencing ${HOME}" 1>&2
    echo "please use \${HOME} instead if that's what you want" 1>&2
fi

# Create CK8S_CONFIG_PATH if it does not exist and make it absolute
CK8S_CONFIG_PATH=$(readlink -m "${CK8S_CONFIG_PATH}")
mkdir -p "${CK8S_CONFIG_PATH}"
export CK8S_CONFIG_PATH

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
root_path="${here}/.."
# shellcheck disable=SC2034
config_defaults_path="${root_path}/config"
# shellcheck disable=SC2034
kubespray_path="${root_path}/kubespray"

config_path="${CK8S_CONFIG_PATH}/${prefix}-config"
sops_config="${CK8S_CONFIG_PATH}/.sops.yaml"
state_path="${CK8S_CONFIG_PATH}/.state"

# Set the path to search for dynamic inventories
export TERRAFORM_STATE_ROOT="${config_path}"

declare -A config
# shellcheck disable=SC2034
config["inventory_file"]="${config_path}/inventory.ini"

declare -A secrets
# shellcheck disable=SC2034
secrets["kube_config"]="${state_path}/kube_config_${prefix}.yaml"

log_info() {
    echo -e "[\e[34mck8s\e[0m] ${*}" 1>&2
}

log_info_no_newline() {
    echo -e -n "[\e[34mck8s\e[0m] ${*}" 1>&2
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

# Checks the current openstack env variables to see if anything is missing.
# The user is then show what is set and prompted if they want to proceed or not.
# The user can still proceed if nothing is set, to allow for other types of cloud providers.
check_openstack_credentials() {
    log_info "Checking for openstack user or openstack application credentials"

    if [ -n "${OS_USERNAME:-}" ] && [ -n "${OS_APPLICATION_CREDENTIAL_NAME:-}" ]; then
        log_error "ERROR: Both OS_USERNAME and OS_APPLICATION_CREDENTIAL_NAME are set."
        log_error "Unset env vars for either the openstack user or the openstack application credentials."
        log_error "Unset openstack user: \"unset OS_USERNAME OS_PASSWORD\""
        log_error "Unset openstack application credentials: \"unset OS_APPLICATION_CREDENTIAL_NAME OS_APPLICATION_CREDENTIAL_ID OS_APPLICATION_CREDENTIAL_SECRET\""
        exit 1
    elif [ -n "${OS_APPLICATION_CREDENTIAL_NAME:-}" ]; then
        if [ -n "${OS_APPLICATION_CREDENTIAL_ID:-}" ] && [ -n "${OS_APPLICATION_CREDENTIAL_SECRET:-}" ]; then
            log_info "Openstack application credentials found"
            log_info "OS_APPLICATION_CREDENTIAL_NAME is: ${OS_APPLICATION_CREDENTIAL_NAME}"
            log_info "OS_APPLICATION_CREDENTIAL_ID is not empty (check contents by running \"echo \$OS_APPLICATION_CREDENTIAL_ID\")"
            log_info "OS_APPLICATION_CREDENTIAL_SECRET is not empty (check contents by running \"echo \$OS_APPLICATION_CREDENTIAL_SECRET\")"
        elif [ -n "${OS_APPLICATION_CREDENTIAL_ID:-}" ]; then
            log_error "ERROR: OS_APPLICATION_CREDENTIAL_NAME and OS_APPLICATION_CREDENTIAL_ID is set but OS_APPLICATION_CREDENTIAL_SECRET is emppty!"
            exit 1
        elif [ -n "${OS_APPLICATION_CREDENTIAL_SECRET:-}" ]; then
            log_error "ERROR: OS_APPLICATION_CREDENTIAL_NAME and OS_APPLICATION_CREDENTIAL_SECRET is set but OS_APPLICATION_CREDENTIAL_ID is emppty!"
            exit 1
        else
            log_error "ERROR: OS_APPLICATION_CREDENTIAL_NAME is set but OS_APPLICATION_CREDENTIAL_ID and OS_APPLICATION_CREDENTIAL_SECRET is emppty!"
            exit 1
        fi
    elif [ -n "${OS_USERNAME:-}" ]; then
        if [ -n "${OS_PASSWORD:-}" ]; then
            log_info "Openstack user found"
            log_info "OS_USERNAME is: ${OS_USERNAME}"
            log_info "OS_PASSWORD is not empty (check contents by running \"echo \$OS_PASSWORD\")"
        else
            log_error "ERROR: OS_USERNAME is set but OS_PASSWORD is empty!"
            exit 1
        fi
    else
        log_warning "Warning: No openstack user or openstack application credentials found."
        log_warning "If you are not running on openstack, then you can safely ignore this."
    fi

    log_info_no_newline "Proceed with the current credentials [y/N]: "
    read -r reply
    if [[ "${reply}" != "y" ]]; then
        exit 1
    fi
}
