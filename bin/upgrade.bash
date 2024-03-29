#!/usr/bin/env bash

here="$(readlink -f "$(dirname "${0}")")"

ROOT="$(readlink -f "${here}/../")"

CK8S_STACK="$(basename "$0")"
export CK8S_STACK
export CK8S_CLUSTER="${1}"

# shellcheck source=scripts/migration/lib.sh
CK8S_ROOT_SCRIPT="true" source "${ROOT}/scripts/migration/lib.sh"

snippets_list() {
  if [[ ! "${1}" =~ ^prepare$ ]]; then
    log_fatal "usage: snippets_list prepare"
  fi

  echo "${ROOT}/migration/${CK8S_TARGET_VERSION}/${1}/"* | sort
}

snippets_check() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^prepare$ ]]; then
    log_fatal "usage: snippets_check prepare <snippets...>"
  fi

  local action="${1}"
  local snippets="${*:2}"

  local pass="true"
  for snippet in ${snippets}; do
    if [[ "$(basename "${snippet}")" == "00-template.sh" ]]; then
      continue
    fi

    if [[ ! -x "${snippet}" ]]; then
      log_error "error: ${action} snippet \"${snippet}\" is invalid (not executable)"
      pass="false"
    fi
  done
  if [ "${pass}" == "false" ]; then
    exit 1
  fi

  log_info "${action} snippets checked\n---"
}

prepare() {
  local snippets
  snippets="$(snippets_list prepare)"

  snippets_check prepare "${snippets}"

  for snippet in ${snippets}; do
    if [[ "$(basename "${snippet}")" == "00-template.sh" ]]; then
      continue
    fi

    log_info "prepare snippet \"${snippet##"${ROOT}/migration/"}\":"
    if "${snippet}"; then
      log_info "prepare snippet success\n---"
    else
      log_fatal "prepare snippet failure"
    fi
  done
}

usage() {
  if [[ -n "${1:-}" ]]; then
    log_error "invalid command \"${1}\"\n"
  else
    log_error "missing command\n"
  fi

  printf "commands:\n" 1>&2
  printf "\t<wc|sc|both> <version> prepare \t- run all prepare steps upgrading the configuration\n" 1>&2

  exit 1
}

main() {
  if [[ ! "${1}" =~ ^(wc|sc|both)$ ]] || [[ ! "${3}" =~ ^prepare$ ]]; then
    usage "${3:-}"
  fi

  local version="${2}"
  local action="${3}"

  local pass="true"
  for dir in "" "prepare"; do
    if [[ ! -d "${ROOT}/migration/${version}/${dir}" ]]; then
      log_error "error: migration/${version}/${dir} is not a directory, did you specify the correct version?"
      pass="false"
    fi
  done
  if [[ "${pass}" = "false" ]]; then
    exit 1
  fi

  export CK8S_TARGET_VERSION="${version}"
  export CK8S_STACK="${version}/${action}"

  check_config

  if [[ "${CK8S_CLUSTER:-}" =~ ^(sc|both)$ ]]; then
    config_load "sc"
    check_version "sc" "${action}"
  fi
  if [[ "${CK8S_CLUSTER:-}" =~ ^(wc|both)$ ]]; then
    config_load "wc"
    check_version "wc" "${action}"
  fi

  "${action}"

  log_info "${action} complete"
}

main "${@}"
