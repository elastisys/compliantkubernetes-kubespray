#!/bin/bash

# This file is not supposed to be executed on it's own, but rather is sourced
# by the other scripts in this path. It holds common paths and functions that
# are used throughout all of the scripts.

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
: "${prefix:?Missing prefix}"

if [[ ! "${prefix}" =~ ^(wc|sc|both)$ ]]; then
  echo "ERROR: invalid value set for \"prefix\", valid values are <wc|sc|both>" 1>&2
  exit 1
fi

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

# Set the path to search for dynamic inventories
export TERRAFORM_STATE_ROOT="${config_path}"

declare -A config
# shellcheck disable=SC2034
config["inventory_file"]="${config_path}/inventory.ini"
# shellcheck disable=SC2034
config["groups_inventory_file"]="${config_path}/groups-inventory.ini"

declare -A KUBE
KUBE[sc]="${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml"
KUBE[wc]="${CK8S_CONFIG_PATH}/.state/kube_config_wc.yaml"

# shellcheck disable=SC2317
log_info() {
  echo -e "[\e[34mck8s\e[0m] ${*}" 1>&2
}

log_info_no_newline() {
  echo -e -n "[\e[34mck8s\e[0m] ${*}" 1>&2
}

log_info() {
  log_info_no_newline "${*}\n"
}

log_warning_no_newline() {
  echo -e -n "[\e[33mck8s\e[0m] ${*}" 1>&2
}

log_warning() {
  log_warning_no_newline "${*}\n"
}

log_error_no_newline() {
  echo -e -n "[\e[31mck8s\e[0m] ${*}" 1>&2
}

log_error() {
  log_error_no_newline "${*}\n"
}

# Checks that all dependencies are available and critical ones for matching minor version.
check_tools() {
  local req

  req="${root_path}/get-requirements.yaml"

  local warn
  local err

  warn=0
  err=0

  for executable in jq yq sops kubectl helm helmfile terraform; do
    if ! command -v "${executable}" >/dev/null; then
      log_error "Required dependency ${executable} missing"
      err=1
    fi
  done

  if [[ "${err}" != 0 ]]; then
    log_error "Install required dependencies before running this command!"
    exit 1
  fi

  check_minor() {
    local v1
    local v2

    v1="$(sed -r -e 's/^v//' -e 's/\.[0-9]$/\.\*/' -e 's/\./\\\./g' -e 's/\*/\.*/g' <<<"${1}")"
    v2="$(sed -nr 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' <<<"${2}")"

    if ! [[ "${v2}" =~ ${v1} ]]; then
      log_warning "Required dependency ${3} not using recommended version: (expected ${1##v} - actual ${v2})"
      warn=1
    fi
  }

  check_minor "$(yq '.[0].vars.terraform_version' "${req}")" "$(terraform --version --json | yq '.terraform_version')" "terraform"

  if [[ "${warn}" != 0 ]]; then
    if [[ -t 1 ]]; then
      log_warning_no_newline "Do you want to abort? (y/N): "
      read -r reply
      if [[ "${reply}" == "y" ]]; then
        exit 1
      fi
    fi
  fi
}

validate_sops_config() {
  if [ ! -f "${sops_config}" ]; then
    log_error "ERROR: SOPS config not found: ${sops_config}"
    exit 1
  fi

  rule_count=$(yq '.creation_rules | length' "${sops_config}")
  if [ "${rule_count:-0}" -gt 1 ]; then
    log_error "ERROR: SOPS config has more than one creation rule."
    exit 1
  fi

  fingerprints=$(yq '.creation_rules[0].pgp' "${sops_config}")
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

  # shellcheck disable=SC2317
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
  yq -n '.creation_rules[0].pgp = "'"${1}"'"' >"${sops_config}" ||
    (log_error "Failed to write fingerprints" && rm "${sops_config}" && exit 1)
}

# Encrypt a file in place.
sops_encrypt() {
  # https://github.com/mozilla/sops/issues/460
  if grep -F -q 'sops:' "${1}" ||
    grep -F -q '"sops":' "${1}" ||
    grep -F -q '[sops]' "${1}" ||
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
  if ! grep -F -q 'sops:' "${1}" &&
    ! grep -F -q '"sops":' "${1}" &&
    ! grep -F -q '[sops]' "${1}" &&
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

# Compares the expected and actual git state of the kubespray submodule.
# If they don't match the user will be asked if they want to continue anyway.
kubespray_version_check() {
  pushd "${here}/../" || exit

  git_diff=$(git diff kubespray/)

  popd || exit

  if [[ $git_diff ]]; then

    expected_commit=$(echo "${git_diff}" | grep -m1 commit | grep -o '[^ ]*$')
    current_commit=$(echo "${git_diff}" | tail -n 1 | grep -o '[^ ]*$')

    log_info "The status of the kubespray git submodule differs from the expected status, either it is on another commit or there are file changes. This can cause unexpected versions to be installed or cause other errors. We recommend that you stop and check what has changed."
    log_info "Expected" "${expected_commit}", "got" "${current_commit}".
    log_info_no_newline "Do you want to abort? (Y/n): "

    read -r reply

    if [[ "${reply}" != "n" ]]; then
      exit 1
    fi
  fi
}

# Compares the checked out version and the config version of ck8s-kubespray.
# Exits if they do not match.
ck8s_kubespray_version_check() {
  pushd "${root_path}" || exit
  version=$(git describe --exact-match --tags 2>/dev/null || git rev-parse HEAD)
  popd || exit
  version_in_config=$(yq .ck8sKubesprayVersion "${config_path}/group_vars/all/ck8s-kubespray-general.yaml")

  if [[ -z "${version_in_config}" || "${version_in_config}" == "null" ]]; then
    log_error "ERROR: No version set. Ensure that ${config_path}/group_vars/all/ck8s-kubespray-general.yaml exists and has ck8sKubesprayVersion set."
    exit 1
  elif [[ "${version_in_config}" != "any" ]] &&
    [[ "${version}" != "${version_in_config}" ]]; then
    log_error ERROR: Version mismatch. Switch to the correct version or update your config version by starting the upgrade process.
    log_error "Config version: ${version_in_config}"
    log_error "CK8S-Kubespray version: ${version}"
    exit 1
  fi
}
with_kubeconfig() {
  kubeconfig="${1}"
  shift

  if [ ! -f "${kubeconfig}" ]; then
    log_error "ERROR: Kubeconfig not found: ${kubeconfig}"
    exit 1
  fi

  if grep -F -q 'sops:' "${kubeconfig}" ||
    grep -F -q '"sops":' "${kubeconfig}" ||
    grep -F -q '[sops]' "${kubeconfig}" ||
    grep -F -q 'sops_version=' "${kubeconfig}"; then
    log_info "Using encrypted kubeconfig ${kubeconfig}"

    # TODO: Can't use a FIFO since we can't know that the kubeconfig is not
    #       read multiple times. Let's try to eliminate the need for writing
    #       the kubeconfig to disk in the future.
    local -a args
    for arg in "${@}"; do args+=("'${arg}'"); done
    sops_exec_file_no_fifo "${kubeconfig}" "KUBECONFIG=\"{}\" ${args[*]}"
  else
    log_info "Using unencrypted kubeconfig ${kubeconfig}"
    KUBECONFIG=${kubeconfig} "${@}"
  fi
}

ops_kubectl() { # <prefix> <args...>
  case "${1}" in
  sc) kubeconfig="${KUBE[sc]}" ;;
  wc) kubeconfig="${KUBE[wc]}" ;;
  esac

  shift
  with_kubeconfig "$kubeconfig" kubectl "${@}"
}

assign_host() {
  local node=$1
  # Check for control plane nodes
  control_plane_label=$(yq .control_plane_label "${config_path}/group_vars/all/ck8s-kubespray-general.yaml")
  # Check for AMS
  primary_group_label=$(yq .group_label_primary "${config_path}/group_vars/all/ck8s-kubespray-general.yaml")
  secondary_group_label=$(yq .group_label_secondary "${config_path}/group_vars/all/ck8s-kubespray-general.yaml")
  if [[ $(ops_kubectl "$prefix" get node "$node" -ojson | jq ".metadata.labels | has(\"${control_plane_label}\")") == "true" ]]; then
    target_group="kube_control_plane"
    if [[ "$(group_exists "${config[groups_inventory_file]}" "$target_group")" != "true" ]]; then
      log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
      add_group "${config[groups_inventory_file]}" "$target_group"
    fi
    add_host_to_group "${config[groups_inventory_file]}" "$node" "$target_group"
  elif [[ $(ops_kubectl "$prefix" get node "$node" -ojson | jq ".metadata.labels | has(\"${primary_group_label}\")") == "true" ]]; then
    node_type=$(ops_kubectl "$prefix" get node "$node" -ojson | jq -r ".metadata.labels[\"${primary_group_label}\"]")
    if [[ $(ops_kubectl "$prefix" get node "$node" -ojson | jq ".metadata.labels | has(\"${secondary_group_label}\")") == "true" ]]; then
      cluster_name=$(ops_kubectl "$prefix" get node "$node" -ojson | jq -r ".metadata.labels[\"${secondary_group_label}\"]")
      target_group="${node_type}_${cluster_name//-/_}"
    else
      target_group="${node_type}"
    fi
    if [[ "$(group_exists "${config[groups_inventory_file]}" "$target_group")" != "true" ]]; then
      log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
      add_group "${config[groups_inventory_file]}" "$target_group"
    fi

    if [[ "$node_type" == "postgres" ]]; then
      if [[ $(ops_kubectl "$prefix" get pods -A -l application=spilo,cluster-name="$cluster_name" -ojson | jq -r '.items[] | select( .metadata.labels["spilo-role"] == "master" ).spec.nodeName') == "$node" ]]; then
        add_host_to_group_as_last "${config[groups_inventory_file]}" "$node" "$target_group"
      else
        add_host_to_group "${config[groups_inventory_file]}" "$node" "$target_group"
      fi
    elif [[ "$node_type" == "redis" ]]; then
      if [[ $(ops_kubectl "$prefix" get pods -A -l redisfailovers.databases.spotahome.com/name="$cluster_name" -ojson | jq -r '.items[] | select( .metadata.labels["redisfailovers-role"] == "master" ).spec.nodeName') == "$node" ]]; then
        add_host_to_group_as_last "${config[groups_inventory_file]}" "$node" "$target_group"
      else
        add_host_to_group "${config[groups_inventory_file]}" "$node" "$target_group"
      fi
    else
      add_host_to_group "${config[groups_inventory_file]}" "$node" "$target_group"
    fi

  # Check for regular nodes
  else
    target_group="regular_worker"
    if [[ "$(group_exists "${config[groups_inventory_file]}" "$target_group")" != "true" ]]; then
      log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
      add_group "${config[groups_inventory_file]}" "$target_group"
    fi
    add_host_to_group "${config[groups_inventory_file]}" "$node" "$target_group"
  fi
}

contains_element() {
  local e match="$1"
  shift
  for e in "$@"; do
    [[ "${e}" == "${match}" ]] && return 0
  done
  return 1
}
