#!/usr/bin/env bash

set -eu

: "${CK8S_CONFIG_PATH:?"CK8S_CONFIG_PATH is unset"}"

if [[ "$1" =~ (sc|wc) ]]; then
    cp "$CK8S_CONFIG_PATH/$1-config/terraform.tfstate" "$CK8S_CONFIG_PATH/$1-config/terraform-temp.tfstate"
    terraformState="$CK8S_CONFIG_PATH/$1-config/terraform-temp.tfstate"
    clusterVars="$CK8S_CONFIG_PATH/$1-config/cluster.tfvars"
    export TF_VAR_inventory_file="$CK8S_CONFIG_PATH/$1-config/inventory-temp.ini"
else
    echo "usage: $0 <sc|wc>"
    exit 1
fi

fetch_attributes() {
    yq4 -oj '[.[].attributes]'
}

fetch_instances() {
    yq4 -oj '[.[].instances[]]'
}

fetch_id() {
    yq4 '.[].id'
}

fetch_index_key () {
    yq4 ".[] | select(.attributes.id == \"${1}\") | .index_key"
}

fetch_master_instances() {
    yq4 -oj '[.resources[] | select(.name == "master_nodes").instances[]]' "$1"
}

import_master_instances() {
    node_id=$1
    node_name=$2
    zone=$3
    # shellcheck disable=SC2086
    terraform import -var-file "${clusterVars}" \
        -state "${terraformState}" \
        -config "${MODULE_PATH_TERRAFORM}" \
        module.kubernetes.exoscale_compute_instance.master[\"${node_name}\"] ${node_id}@${zone}
}

fetch_worker_instances() {
    yq4 -oj '[.resources[] | select(.name == "worker_nodes").instances[]]' "$1"
}

import_worker_instances() {
    node_id=$1
    node_name=$2
    zone=$3
    # shellcheck disable=SC2086
    terraform import -var-file "${clusterVars}" \
        -state "${terraformState}" \
        -config "${MODULE_PATH_TERRAFORM}" \
        module.kubernetes.exoscale_compute_instance.worker[\"${node_name}\"] ${node_id}@${zone}
}

fetch_private_network() {
    yq4 -oj '[.resources[] | select(.name == "private_network")]' "$1"
}

fetch_exoscale_ipaddress(){
    yq4 -oj "[.resources[] | select(.type == \"exoscale_ipaddress\" and (.name == \"$2\"))]" "$1"
}

import_private_network() {
    network_id=$1
    zone=$2
    # shellcheck disable=SC2086
    terraform import -var-file "${clusterVars}" \
        -state "${terraformState}" \
        -config "${MODULE_PATH_TERRAFORM}" \
        module.kubernetes.exoscale_private_network.private_network ${network_id}@${zone}
}

import_elastic_ip(){
    elastic_ip_id=$1
    elastic_ip_name=$2
    zone=$3
    # shellcheck disable=SC2086
    terraform import -var-file "${clusterVars}" \
        -state "${terraformState}" \
        -config "${MODULE_PATH_TERRAFORM}" \
        module.kubernetes.exoscale_elastic_ip.${elastic_ip_name} ${elastic_ip_id}@${zone}
}

remove_old_instance() {
    yq4 -ioj "del( .resources[] | select(.name == \"${2}\" and .type == \"${3}\") )" "$1"
}

pushd "$CK8S_CONFIG_PATH/$1-config"

terraform init -upgrade -var-file "${clusterVars}" "${MODULE_PATH_TERRAFORM}"

ingress_controller_lb_id=$(fetch_exoscale_ipaddress "${terraformState}" ingress_controller_lb | fetch_instances | fetch_attributes | fetch_id)
control_plane_lb_id=$(fetch_exoscale_ipaddress "${terraformState}" control_plane_lb | fetch_instances | fetch_attributes | fetch_id)
import_elastic_ip "${ingress_controller_lb_id}" ingress_controller_lb ch-gva-2
import_elastic_ip "${control_plane_lb_id}" control_plane_lb ch-gva-2

# shellcheck disable=SC2207
master_nodes=( $(fetch_master_instances "${terraformState}" | fetch_attributes | fetch_id) )
for node_id in "${master_nodes[@]}"; do
    node_name=$(fetch_master_instances "${terraformState}" | fetch_index_key "${node_id}" )
    import_master_instances "${node_id}" "${node_name}" ch-gva-2
done

# shellcheck disable=SC2207
worker_nodes=( $(fetch_worker_instances "${terraformState}" | fetch_attributes | fetch_id) )
for node_id in "${worker_nodes[@]}"; do
    node_name=$(fetch_worker_instances "${terraformState}" | fetch_index_key "${node_id}" )
    import_worker_instances "${node_id}" "${node_name}" ch-gva-2
done

network_id=$(fetch_private_network "${terraformState}" | fetch_instances | fetch_attributes | fetch_id)
import_private_network "${network_id}" ch-gva-2

remove_old_instance "${terraformState}" master exoscale_compute
remove_old_instance "${terraformState}" worker exoscale_compute

remove_old_instance "${terraformState}" master_nodes exoscale_compute
remove_old_instance "${terraformState}" worker_nodes exoscale_compute

remove_old_instance "${terraformState}" private_network exoscale_network

remove_old_instance "${terraformState}" control_plane_lb exoscale_secondary_ipaddress
remove_old_instance "${terraformState}" ingress_controller_lb exoscale_secondary_ipaddress

remove_old_instance "${terraformState}" control_plane_lb exoscale_ipaddress
remove_old_instance "${terraformState}" ingress_controller_lb exoscale_ipaddress

remove_old_instance "${terraformState}" master_private_network_nic exoscale_nic
remove_old_instance "${terraformState}" worker_private_network_nic exoscale_nic

terraform plan -var-file "${clusterVars}" -state "${terraformState}" "${MODULE_PATH_TERRAFORM}"

popd
