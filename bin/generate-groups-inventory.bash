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
    log_info_no_newline "${config[groups_inventory_file]} will be overwritten, Proceed [y/N] ? "
    read -r reply
    if [[ "${reply}" != "y" ]]; then
        exit 1
    fi
fi

if [[ "$(groupExists ${config[inventory_file]} all)" == "true" ]]; then
    all_section="$(getSection ${config[inventory_file]} all)"
    echo -e "$all_section\n" > ${config[groups_inventory_file]}
else 
    log_error "Error: [all] group in defined in ${config[inventory_file]}"
fi

if [[ "$(groupExists ${config[inventory_file]} etcd)" == "true" ]]; then
    etcd_section="$(getSection ${config[inventory_file]} etcd)"
    echo -e "$etcd_section" >> ${config[groups_inventory_file]}
else 
    log_error "Error: [etcd] group in defined in ${config[inventory_file]}"
fi


nodes=$(ops_kubectl $prefix get nodes -o=jsonpath='{.items[*].metadata.name}')

for node in $nodes; do
    # Check for control plane nodes
    if [[ $(ops_kubectl $prefix get node "$node" -ojson | jq '.metadata.labels | has("node-role.kubernetes.io/control-plane")') == "true" ]]; then
        target_group="kube_control_plane"
        if [[ "$(groupExists ${config[groups_inventory_file]} $target_group)" != "true" ]]; then
            log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
            addGroup "${config[groups_inventory_file]}" "$target_group"
        fi
        addHostToGroup "${config[groups_inventory_file]}" "$node" "$target_group"
    elif [[ $(ops_kubectl $prefix get node "$node" -ojson | jq '.metadata.labels | has("elastisys.io/node-type")') == "true" ]]; then
        node_type=$(ops_kubectl $prefix get node "$node" -ojson | jq -r '.metadata.labels["elastisys.io/node-type"]')
        cluster_name=$(ops_kubectl $prefix get node "$node" -ojson | jq -r '.metadata.labels["elastisys.io/ams-cluster-name"]')
        target_group="${node_type}_${cluster_name}"
        if [[ "$(groupExists ${config[groups_inventory_file]} $target_group)" != "true" ]]; then
            log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
            addGroup "${config[groups_inventory_file]}" "$target_group"
        fi
        addHostToGroup "${config[groups_inventory_file]}" "$node" "$target_group"
    else
        target_group="regular_worker"
        if [[ "$(groupExists ${config[groups_inventory_file]} $target_group)" != "true" ]]; then
            log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
            addGroup "${config[groups_inventory_file]}" "$target_group"
        fi
        addHostToGroup "${config[groups_inventory_file]}" "$node" "$target_group"
    fi
done