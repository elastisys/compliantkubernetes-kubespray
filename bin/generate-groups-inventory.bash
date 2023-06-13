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

# Group Redis Clusters
target_group="redis_node_"
redis_nodes=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=redis -o=jsonpath='{.items[*].metadata.name}')
redis_clusters=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=redis  -ojson | jq  '.items[].metadata.labels["elastisys.io/ams-cluster-name"]' | jq -r -s '. | unique | .[]')

if [[ ${redis_nodes} ]]; then

    for cluster in $redis_clusters; do 
        target_group="redis_node_$cluster"
        if [[ "$(groupExists "${config[groups_inventory_file]}" "$target_group")" != "true" ]]; then
            log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
            addGroup "${config[groups_inventory_file]}" "$target_group"
        fi
        cluster_nodes=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=redis  -ojson | jq -r ".items[] | select(.metadata.labels[\"elastisys.io/ams-cluster-name\"] == \"$cluster\") | .metadata.name")
        for node in $cluster_nodes; do 
            addHostToGroup "${config[groups_inventory_file]}" "$node" "$target_group"
        done
    done

fi

# Group Postgres Clusters
target_group="postgres_node_"
postgres_nodes=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=postgres -o=jsonpath='{.items[*].metadata.name}')
postgres_clusters=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=postgres  -ojson | jq  '.items[].metadata.labels["elastisys.io/ams-cluster-name"]' | jq -r -s '. | unique | .[]')

if [[ ${postgres_nodes} ]]; then

    for cluster in $postgres_clusters; do 
        target_group="postgres_node_$cluster"
        if [[ "$(groupExists "${config[groups_inventory_file]}" "$target_group")" != "true" ]]; then
            log_info "Adding $target_group group to ${config[groups_inventory_file]} .."
            addGroup "${config[groups_inventory_file]}" "$target_group"
        fi
        cluster_nodes=$(ops_kubectl $prefix get nodes -l elastisys.io/node-type=postgres  -ojson | jq -r ".items[] | select(.metadata.labels[\"elastisys.io/ams-cluster-name\"] == \"$cluster\") | .metadata.name")
        for node in $cluster_nodes; do 
            addHostToGroup "${config[groups_inventory_file]}" "$node" "$target_group"
        done
    done

fi

# Group Jaeger Clusters
target_group="jaeger_node_"
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
