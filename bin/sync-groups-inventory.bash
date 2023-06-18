#!/bin/bash

set -eu -o pipefail


here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

# shellcheck source=bin/common.bash
source "${here}/inventory-parser.bash"


log_info "Inventories sync in process .."

for host in $(getGroupHosts ${config[groups_inventory_file]} all); do 
    if $(! containsElement $host $(getGroupHosts ${config[inventory_file]} all)); then
        log_info "Removing $host from groups inventory.."
        removeHostFromGroup "${config[groups_inventory_file]}" $host "all" 
    fi
done

for host in $(getGroupHosts ${config[inventory_file]} all); do 
    if $(! containsElement $host $(getGroupHosts ${config[groups_inventory_file]} all)); then
        log_info "Adding $host to groups inventory.."
        addHostToGroup "${config[groups_inventory_file]}" $host "all"
        hostvars=$(getHostVars ${config[inventory_file]} $host)
        log_info "Syncing hostvars for new host: $host .."
        for hostvar in $hostvars; do 
            value=$(getHostVar ${config[inventory_file]} $host $hostvar)
            setHostVar ${config[groups_inventory_file]} $host $hostvar $value
        done
        assignHost $host
    fi
done

for host in $(getGroupHosts ${config[groups_inventory_file]} all); do 
    hostvars=$(getHostVars ${config[inventory_file]} $host)
    log_info "Syncing hostvars for existing host: $host"
    for hostvar in $hostvars; do 
        value=$(getHostVar ${config[inventory_file]} $host $hostvar)
        updateHostVar ${config[groups_inventory_file]} $host $hostvar $value
    done
done