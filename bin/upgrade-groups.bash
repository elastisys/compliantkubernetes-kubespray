#!/bin/bash

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
usage() {
    echo "COMMANDS:" 1>&2
    echo " list-groups                      List groups " 1>&2
    echo " apply                   Run upgrade playbook " 1>&2
    echo "  args: [--skip-download]" 1>&2
    exit 1
}

# shellcheck source=bin/common.bash
source "${here}/common.bash"

# shellcheck source=bin/common.bash
source "${here}/inventory-parser.bash"

list_groups() {
    groups=$(read_inventory_groups "${config[groups_inventory_file]}")
    for group in $groups; do
      if ! [[ "${group}" =~ ^(all|etcd|kube_node|k8s_cluster|.*:.*)$ ]]; then
        log_info "- Group: ${group}"
        for host in $(get_group_hosts "${config[groups_inventory_file]}" "${group}"); do
          echo -e "\t\t* ${host}"
        done
      fi
    done
}

apply() {
    # shellcheck disable=SC2207
    all_nodes=($(get_group_hosts "${config[groups_inventory_file]}" "all"))
    total_nodes=${#all_nodes[@]}
    ansible_user=$(get_host_var "${config[inventory_file]}" "${all_nodes[0]}" "ansible_user")
    if [[ -z "${ansible_user}" ]] ||  [[ "${ansible_user}" == "null" ]]; then
      ansible_user="ubuntu"
    fi

    local -a groups
    for group in $(read_inventory_groups "${config[groups_inventory_file]}" | sort); do
      if ! [[ "${group}" =~ ^(all|kube_control_plane|etcd|kube_node|k8s_cluster|.*:.*)$ ]]; then
        groups+=("${group}")
      fi
    done
    local -A group_lengths
    for group in "${groups[@]}"; do
      group_lengths["${group}"]="$(get_group_hosts "${config[groups_inventory_file]}" "${group}" | wc -w)"
    done

    pushd "${kubespray_path}"
    skip_tags="multus"
    if [[ "${1}" == "--skip-download" ]]; then
      skip_tags+=",download"
    fi
    ansible-playbook upgrade-cluster.yml -b -i "${config[groups_inventory_file]}" --skip-tags=${skip_tags} --limit "kube_control_plane" -e serial=1

    for index in $(seq 0 "${total_nodes}"); do
      local -a limit
      limit=()
      for group in "${groups[@]}"; do
        if [[ "${index}" -lt "${group_lengths["${group}"]}" ]]; then
          limit+=("${group}[${index}]")
        fi
      done
      if [[ -z "${limit[*]}" ]]; then
        break
      fi
      ansible-playbook upgrade-cluster.yml -b -i "${config[groups_inventory_file]}" --skip-tags=${skip_tags} --limit "$(tr ' ' ',' <<< "${limit[*]}")" -e serial=100%
    done

    popd
}


case "${1}" in
    list-groups)
        list_groups
        ;;
    apply)
        apply "$*"
        ;;
    *) usage ;;
esac
