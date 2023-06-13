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


# Control Plane Nodes 
target_group="kube_control_plane"
control_plane_nodes=$(ops_kubectl $prefix get nodes -l node-role.kubernetes.io/control-plane -o=jsonpath='{.items[*].metadata.name}')
if [[ ${control_plane_nodes} ]]; then
    if [[ "$(groupExists ${config[groups_inventory_file]} $target_group)" != "true" ]]; then
        log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
        addGroup "${config[groups_inventory_file]}" "$target_group"
    fi
    for node in $control_plane_nodes; do
        addHostToGroup "${config[groups_inventory_file]}" "$node" "$target_group"
    done
fi

# Worker Nodes
target_group="kube_node"
worker_nodes=$(ops_kubectl $prefix get nodes -l '!node-role.kubernetes.io/control-plane' -o=jsonpath='{.items[*].metadata.name}')
if [[ ${worker_nodes} ]]; then
    if [[ "$(groupExists ${config[groups_inventory_file]} $target_group)" != "true" ]]; then
        log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
        addGroup "${config[groups_inventory_file]}" "$target_group"
    fi
    for node in $worker_nodes; do
        addHostToGroup "${config[groups_inventory_file]}" "$node" "$target_group"
    done
fi

# Elastisys Nodes
target_group="elastisys_node"
elastisys_nodes=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=elastisys -o=jsonpath='{.items[*].metadata.name}')

if [[ ${elastisys_nodes} ]]; then
    if [[ "$(groupExists ${config[groups_inventory_file]} $target_group)" != "true" ]]; then
        log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
        addGroup "${config[groups_inventory_file]}" "$target_group"
    fi
    for node in $elastisys_nodes; do
        addHostToGroup "${config[groups_inventory_file]}" "$node" "$target_group"
    done
fi

# Redis Clusters
redis_nodes=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=redis -o=jsonpath='{.items[*].metadata.name}')
redis_clusters=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=redis  -ojson | jq  '.items[].metadata.labels["elastisys.io/ams-cluster-name"]' | jq -r -s '. | unique | .[]')

if [[ ${redis_nodes} ]]; then

    for cluster in $redis_clusters; do 
        target_group="redis_node_$cluster"
        if [[ "$(groupExists ${config[groups_inventory_file]} $target_group)" != "true" ]]; then
            log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
            addGroup "${config[groups_inventory_file]}" "$target_group"
        fi
        cluster_nodes=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=redis  -ojson | jq -r ".items[] | select(.metadata.labels[\"elastisys.io/ams-cluster-name\"] == \"$cluster\") | .metadata.name")
        for node in $cluster_nodes; do 
            addHostToGroup "${config[groups_inventory_file]}" "$node" "$target_group"
        done
    done

fi

# Postgres Clusters
postgres_nodes=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=postgres -o=jsonpath='{.items[*].metadata.name}')
postgres_clusters=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=postgres  -ojson | jq  '.items[].metadata.labels["elastisys.io/ams-cluster-name"]' | jq -r -s '. | unique | .[]')

if [[ ${postgres_nodes} ]]; then

    for cluster in $postgres_clusters; do 
        target_group="postgres_node_$cluster"
        if [[ "$(groupExists ${config[groups_inventory_file]} $target_group)" != "true" ]]; then
            log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
            addGroup "${config[groups_inventory_file]}" "$target_group"
        fi
        cluster_nodes=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=postgres  -ojson | jq -r ".items[] | select(.metadata.labels[\"elastisys.io/ams-cluster-name\"] == \"$cluster\") | .metadata.name")
        for node in $cluster_nodes; do 
            addHostToGroup "${config[groups_inventory_file]}" "$node" "$target_group"
        done
    done

fi

# Jaeger Clusters
jaeger_nodes=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=jaeger -o=jsonpath='{.items[*].metadata.name}')
jaeger_clusters=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=jaeger  -ojson | jq  '.items[].metadata.labels["elastisys.io/ams-cluster-name"]' | jq -r -s '. | unique | .[]')

if [[ ${jaeger_nodes} ]]; then

    for cluster in $jaeger_clusters; do 
        target_group="jaeger_node_$cluster"
        if [[ "$(groupExists "${config[groups_inventory_file]}" "$target_group")" != "true" ]]; then
            log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
            addGroup "${config[groups_inventory_file]}" "$target_group"
        fi
        cluster_nodes=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=jaeger  -ojson | jq -r ".items[] | select(.metadata.labels[\"elastisys.io/ams-cluster-name\"] == \"$cluster\") | .metadata.name")
        for node in $cluster_nodes; do 
            addHostToGroup "${config[groups_inventory_file]}" "$node" "$target_group"
        done
    done

fi
