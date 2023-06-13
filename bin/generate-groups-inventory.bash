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
    assignHost $node
done