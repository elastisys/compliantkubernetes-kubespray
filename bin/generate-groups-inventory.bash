#!/bin/bash

set -eu -o pipefail


here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

# shellcheck source=bin/common.bash
source "${here}/inventory-parser.bash"

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
    log_error "Error: [all] group is defined in ${config[inventory_file]}"
fi

if [[ "$(groupExists ${config[inventory_file]} etcd)" == "true" ]]; then
    etcd_section="$(getSection ${config[inventory_file]} etcd)"
    echo -e "$etcd_section\n" >> ${config[groups_inventory_file]}
else 
    log_error "Error: [etcd] group is defined in ${config[inventory_file]}"
fi

if [[ "$(groupExists ${config[inventory_file]} kube_node)" == "true" ]]; then
    kube_node_section="$(getSection ${config[inventory_file]} kube_node)"
    echo -e "$kube_node_section\n" >> ${config[groups_inventory_file]}
else 
    log_error "Error: [kube_node] group is defined in ${config[inventory_file]}"
fi

if [[ "$(groupExists ${config[inventory_file]} k8s_cluster:children)" == "true" ]]; then
    k8s_children_section="$(getSection ${config[inventory_file]} k8s_cluster:children)"
    echo -e "$k8s_children_section" >> ${config[groups_inventory_file]}
else 
    log_error "Error: [k8s_cluster:children] group is defined in ${config[inventory_file]}"
fi


nodes=$(ops_kubectl $prefix get nodes -o=jsonpath='{.items[*].metadata.name}')

for node in $nodes; do
    assignHost $node
done