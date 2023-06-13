#!/bin/bash

set -eu -o pipefail


here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

# shellcheck source=bin/common.bash
source "${here}/inventory-parser.bash"

declare -A KUBE
KUBE[sc]="${CK8S_CONFIG_PATH:-}/.state/kube_config_sc.yaml"
KUBE[wc]="${CK8S_CONFIG_PATH:-}/.state/kube_config_wc.yaml"

ops_kubectl() { # <prefix> <args...>
    case "${1}" in
        sc) kubeconfig="${KUBE[sc]}" ;;
        wc) kubeconfig="${KUBE[wc]}" ;;
    esac

    shift
    with_kubeconfig "$kubeconfig" kubectl "${@}"
}


if [ -e "${config[groups_inventory_file]}" ]; then 
    log_info "Using ${config[groups_inventory_file]} .."
else 
    log_info "Creating ${config[groups_inventory_file]} .."
    cp "${config[inventory_file]}" "${config[groups_inventory_file]}"
fi


# Group Elastisys Nodes
target_group="elastisys_node"
elastisys_nodes=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=elastisys -o=jsonpath='{.items[*].metadata.name}')

if [[ ${elastisys_nodes} ]]; then
    if [[ "$(groupExists "${config[groups_inventory_file]}" "$target_group")" != "true" ]]; then
        log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
        addGroup "${config[groups_inventory_file]}" "$target_group"
    fi
    for node in $elastisys_nodes; do
        addHostToGroup "${config[groups_inventory_file]}" "$node" "$target_group"
    done

fi


