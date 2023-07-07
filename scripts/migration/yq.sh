#!/usr/bin/env bash

yq_null() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: yq_null <sc|wc> <file> <target>"
  fi

  test "$(yq4 "${3}" "${CK8S_CONFIG_PATH}/${1}-config/group_vars/${2}.yaml")" = "null"
}

yq_check() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: yq_check <sc|wc> <file> <target> <value>"
  fi

  test "$(yq4 "${3}" "${CK8S_CONFIG_PATH}/${1}-config/group_vars/${2}.yaml")" = "$4"
}

yq_copy() {
  if [[ "${#}" -lt 4 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: yq_copy <sc|wc> <file> <source> <destination>"
  fi

  if ! yq_null "${1}" "${2}" "${3}"; then
    log_info "  - copy: ${3} to ${4}"
    yq4 -i "${4} = ${3}" "${CK8S_CONFIG_PATH}/${1}-config/group_vars/${2}.yaml"
  fi
}

yq_move() {
  if [[ "${#}" -lt 4 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: yq_move <sc|wc> <file> <source> <destination>"
  fi

  if ! yq_null "${1}" "${2}" "${3}"; then
    log_info "  - move: ${3} to ${4}"
    yq4 -i "${4} = ${3} | del(${3})" "${CK8S_CONFIG_PATH}/${1}-config/group_vars/${2}.yaml"
  fi
}

yq_add() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: yq_add <sc|wc> <file> <destination> <value>"
  fi

  log_info "  - add: ${4} to ${3}"
  yq4 -i "$3 = $4" "$CK8S_CONFIG_PATH/$1-config/group_vars/${2}.yaml"
}

yq_remove() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: yq_remove <sc|wc> <file> <target>"
  fi

  if ! yq_null "${1}" "${2}" "${3}"; then
    log_info "  - remove: ${3}"
    yq4 -i "del(${3})" "${CK8S_CONFIG_PATH}/${1}-config/group_vars/${2}.yaml"
  fi
}

yq_merge() {
  yq4 eval-all --prettyPrint "... comments=\"\" | explode(.) as \$item ireduce ({}; . * \$item )" "${@}"
}

yq_paths() {
  yq4 "[.. | select(tag != \"!!map\" and . == \"${1}\") | path | with(.[]; . = (\"\\\"\" + .) + \"\\\"\") | \".\" + join \".\" | sub(\"\\.\\\"[0-9]\\\"+.*\"; \"\")] | sort | unique | .[]"
}
