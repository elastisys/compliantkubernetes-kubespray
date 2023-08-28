#!/bin/bash

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
usage() {
    echo "COMMANDS:" 1>&2
    echo "  <prefix> list-groups                    List groups " 1>&2
    echo "      args: [<options>]" 1>&2
    echo "  <prefix> upgrade-groups                    Run upgrade playbook " 1>&2
    echo "      args: [--skip-download]" 1>&2
    exit 1
}


if [ $# -lt 2 ]; then
    usage
else
    export prefix="${1}"
fi

# shellcheck source=bin/common.bash
source "${here}/common.bash"

# shellcheck source=bin/common.bash
source "${here}/inventory-parser.bash"

list_groups() {
    groups=$(readInventoryGroups ${config[groups_inventory_file]})
    for group in $groups; do
        log_info "- $group"
    done
}

upgrade_groups() {
    local -a groups
    for group in $(readInventoryGroups "${config[groups_inventory_file]}" | sort); do
      if ! [[ "${group}" =~ ^(all|etcd|kube_node|.*:.*)$ ]]; then
        groups+=("${group}")
      fi
    done

    local -A group_lengths
    group_lengths["kube_control_plane"]="$(getGroupHosts "${config[groups_inventory_file]}" "kube_control_plane" | wc -w)"
    for group in "${groups[@]}"; do
      group_lengths["${group}"]="$(getGroupHosts "${config[groups_inventory_file]}" "${group}" | wc -w)"
    done

    pushd "${kubespray_path}"
    skip_tags="multus"
    if [[ "${1}" == "--skip-download" ]]; then
      skip_tags+=",download"
    fi
    ansible-playbook upgrade-cluster.yml -b -i "${config[groups_inventory_file]}" --skip-tags=${skip_tags} --limit "kube_control_plane[0]"

    for index in $(seq 0 100); do
      local -a limit
      limit=()
      for group in "${groups[@]}"; do
        if [[ "${group}" == "kube_control_plane" ]]; then
          if [[ "$((index+1))" -lt "${group_lengths["${group}"]}" ]]; then
            limit+=("${group}[$((index+1))]")
          fi
        elif [[ "${index}" -lt "${group_lengths["${group}"]}" ]]; then
          limit+=("${group}[${index}]")
        fi
      done
      if [[ -z "${limit[*]}" ]]; then
        break
      fi
      ansible-playbook upgrade-cluster.yml -uroot -b -i "${config[groups_inventory_file]}" --skip-tags=${skip_tags} --limit "$(tr ' ' ',' <<< "${limit[*]}")" -e serial=100%
    done

    popd
}


case "${2}" in
    list-groups)
        shift 2
        list_groups
        ;;
    upgrade-groups)
        shift 2
        upgrade_groups "${@}"
        ;;
    *) usage ;;
esac
