#!/usr/bin/env bash

set -euo pipefail

THIS="$(basename "$(readlink -f "${0}")")"

declare -A CONFIG
declare -A VERSION

declare -a CONFIG_FILES
CONFIG_FILES=(
  "sc-config/group_vars/all/ck8s-kubespray-general.yaml"
  "sc-config/group_vars/all/ck8s-ssh-keys.yaml"
  "sc-config/group_vars/etcd/ck8s-etcd.yaml"
  "sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml"
  "wc-config/group_vars/all/ck8s-kubespray-general.yaml"
  "wc-config/group_vars/all/ck8s-ssh-keys.yaml"
  "wc-config/group_vars/etcd/ck8s-etcd.yaml"
  "wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml"
)

declare -a SC_CONFIG_FILES
SC_CONFIG_FILES=(
  "sc-config/group_vars/all/ck8s-kubespray-general.yaml"
  "sc-config/group_vars/all/ck8s-ssh-keys.yaml"
  "sc-config/group_vars/etcd/ck8s-etcd.yaml"
  "sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml"
)

declare -a WC_CONFIG_FILES
WC_CONFIG_FILES=(
  "wc-config/group_vars/all/ck8s-kubespray-general.yaml"
  "wc-config/group_vars/all/ck8s-ssh-keys.yaml"
  "wc-config/group_vars/etcd/ck8s-etcd.yaml"
  "wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml"
)

# --- logging functions ---

log_info_no_newline() {
  echo -e -n "[\e[34mck8s\e[0m] ${CK8S_STACK}: ${*}" 1>&2
}

log_info() {
  log_info_no_newline "${*}\n"
}

log_warn_no_newline() {
  echo -e -n "[\e[33mck8s\e[0m] ${CK8S_STACK}: ${*}" 1>&2
}

log_warn() {
  log_warn_no_newline "${*}\n"
}

log_error_no_newline() {
  echo -e -n "[\e[31mck8s\e[0m] ${CK8S_STACK}: ${*}" 1>&2
}

log_error() {
  log_error_no_newline "${*}\n"
}

log_fatal() {
  log_error "${*}"
  exit 1
}

# --- git version

git_version() {
  git -C "${ROOT}" describe --exact-match --tags 2> /dev/null || git -C "${ROOT}" rev-parse HEAD
}

# --- config functions ---

# Usage: config_version <sc|wc>
config_version() {
  if [[ ! "${1:-}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: config_version <sc|wc>"
  fi

  local prefix="${1}"

  local version
  version="$(yq4 ".ck8sKubesprayVersion" <<< "${CONFIG["${prefix}"]}")"

  VERSION["${prefix}-config"]="${version}"
  version="${version#v}"
  VERSION["${prefix}-config-major"]="${version%%.*}"
  version="${version#*.}"
  VERSION["${prefix}-config-minor"]="${version%%.*}"
  version="${version#*.}"
  VERSION["${prefix}-config-patch"]="${version%%-*}"
  version="${version#*-}"
  VERSION["${prefix}-config-ck8spatch"]="${version}"
}

# Usage: config_load <sc|wc>
config_load() {
  case "${1:-}" in
  sc)
    log_info "loading ${1}-config"
    CONFIG[sc]="$(yq_merge "${SC_CONFIG_FILES[@]/#/"$CK8S_CONFIG_PATH/"}")"
    config_version sc
    ;;
  wc)
    log_info "loading ${1}-config"
    CONFIG[wc]="$(yq_merge "${WC_CONFIG_FILES[@]/#/"$CK8S_CONFIG_PATH/"}")"
    config_version wc
    ;;
  *)
    log_fatal "usage: config_load <sc|wc>"
    ;;
  esac
}

check_sops() {
  grep -qs "sops:\\|\"sops\":\\|\\[sops\\]\\|sops_version=" "${1:-/dev/null}"
}

check_config() {
  if [ -z "${THIS:-}" ]; then
    log_fatal "error: \"THIS\" is unset"
  elif [ -z "${ROOT:-}" ]; then
    log_fatal "error: \"ROOT\" is unset"
  elif [ -z "${CK8S_CONFIG_PATH:-}" ]; then
    log_fatal "error: \"CK8S_CONFIG_PATH\" is unset"
  elif [ ! -d "${CK8S_CONFIG_PATH}" ]; then
    log_fatal "error: \"CK8S_CONFIG_PATH\" is not a directory"
  fi

  log_info "using config path: \"${CK8S_CONFIG_PATH}\""

  local pass="true"
  for FILE in "${CONFIG_FILES[@]}"; do
    if [ ! -f "${CK8S_CONFIG_PATH}/${FILE}" ]; then
      log_error "error: \"${FILE}\" is not a file"
      pass="false"
    fi
  done

  if [[ "${pass}" = "false" ]]; then
    exit 1
  fi
}

# usage: check_version <sc|wc> prepare
check_version() {
  if [[ ! "${1:-}" =~ ^(sc|wc)$ ]] || [[ ! "${2:-}" =~ ^prepare$ ]]; then
    log_fatal "usage: check_version <sc|wc> prepare"
  elif [ -z "${CK8S_TARGET_VERSION:-}" ]; then
    log_fatal "error: \"CK8S_TARGET_VERSION\" is unset"
  fi

  if [ "${VERSION["${1}-config"]}" = "any" ]; then
    log_warn "skipping version validation of ${1}-config for version \"${VERSION["${1}-config"]}\""
    return
  elif [[ ! "${VERSION["${1}-config"]}" =~ v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    log_warn "reducing version validation of ${1}-config for version \"${VERSION["${1}-config"]}\""
  else
    log_info "version validation of ${1}-config for version \"${VERSION["${1}-config"]}\""

    local version="${CK8S_TARGET_VERSION##v}"
    local major="${version%%.*}"
    local minor="${version##*.}"

    case "${2:-}" in
    prepare)
      if [ $((major - 1)) -eq "${VERSION["${1}-config-major"]}" ]; then
        if [ $((minor)) -eq 0 ]; then
          log_info "valid upgrade path to next major version \"v${major}.${minor}\""
        else
          log_fatal "invalid upgrade path to major version \"v${major}.${minor}\""
        fi
      elif [ $((major)) -eq "${VERSION["${1}-config-major"]}" ]; then
        if [ $((minor - 1)) -eq "${VERSION["${1}-config-minor"]}" ]; then
          log_info "valid upgrade path to next minor version \"v${major}.${minor}\""
        elif [ $((minor)) -eq "${VERSION["${1}-config-minor"]}" ]; then
          log_info "valid upgrade path to patch version \"v${major}.${minor}\""
        else
          log_fatal "invalid upgrade path to minor version \"v${major}.${minor}\""
        fi
      else
        log_fatal "invalid upgrade path to version \"v${major}.${minor}\""
      fi
      ;;

    apply)
      if [ $((major)) -eq "${VERSION["${1}-config-major"]}" ] && [ $((minor)) -eq "${VERSION["${1}-config-minor"]}" ]; then
        log_info "valid upgrade path to version \"v${major}.${minor}\""
      else
        log_fatal "invalid upgrade path to version \"v${major}.${minor}\""
      fi
      ;;
    esac
  fi

  local repo_version
  repo_version="$(git_version)"
  if [[ "${repo_version%.*}" == "${CK8S_TARGET_VERSION}" ]]; then
    log_info "valid repository version \"${repo_version}\""
  elif [[ "${repo_version}" == "${VERSION["${1}-config"]}" ]]; then
    log_warn "valid repository version \"${repo_version}\""
  else
    log_fatal "invalid repository version \"${repo_version}\""
  fi
}

# Root scripts need to manage this themselves
if [ -z "${CK8S_ROOT_SCRIPT:-}" ]; then
  if [ -z "${CK8S_STACK:-}" ]; then
    export CK8S_STACK="${THIS}"
  else
    export CK8S_STACK="${CK8S_STACK:-}/${THIS}"
  fi

  check_config
fi

# shellcheck source=scripts/migration/yq.sh
source "${ROOT}/scripts/migration/yq.sh"
