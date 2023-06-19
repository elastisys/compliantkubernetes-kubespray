#!/bin/bash

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
usage() {
    echo "COMMANDS:" 1>&2
    echo "  <prefix> logs                              Check group upgrade logs" 1>&2
    echo "      args: <group> [<options>]" 1>&2
    echo "  <prefix> list-groups                    List groups " 1>&2
    echo "      args: [<options>]" 1>&2
    echo "  <prefix> upgrade-groups                    Run upgrade playbook " 1>&2
    echo "      args: [<options>]" 1>&2
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
    kube_version=$1
    groups=$(readInventoryGroups ${config[groups_inventory_file]})
    excluded_groups=(all kube_node kube_control_plane k8s_cluster:children etcd)
    log_info "Getting facts"
    ansible-playbook ${$kubespray_path}/playbooks/facts.yml -uroot -b -i "${config[groups_inventory_file]}"
    log_info "Upgrading first controle plane"
    ansible-playbook ${kubespray_path}/upgrade-cluster.yml -uroot -b -i "${config[groups_inventory_file]}" --skip-tags=multus -e kube_version=${kube_version} --limit "kube_control_plane[0]:etcd[0]"

    kube_control_plane_hosts=$(getGroupHosts ${config[groups_inventory_file]} kube_control_plane)
    kube_control_plane_hosts=($kube_control_plane_hosts)

    if [[ ${#kube_control_plane_hosts[@]} -gt 1 ]]; then 
        ansible-playbook ${kubespray_path}/upgrade-cluster.yml -uroot -b -i "${config[groups_inventory_file]}" --skip-tags=multus -e kube_version=${kube_version} -e serial=1 --limit "kube_control_plane[1:]:etcd[1:]" > /tmp/kube_controle_plane.logs &
    fi 
    for group in $groups; do 
        if $(! containsElement $group ${excluded_groups[@]}) ; then
            ansible-playbook upgrade-cluster.yml -uroot -b -i "${config[groups_inventory_file]}" --skip-tags=multus -e kube_version=${kube_version} -e serial=1 --limit "$group" > /tmp/$group.logs &
        fi
    done
}

get_group_logs() {
    group=$1
    shift
    tail /tmp/$group.logs "${@}"
}

case "${2}" in
    logs)
        shift 2
        get_group_logs "${@}"
        ;;
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
