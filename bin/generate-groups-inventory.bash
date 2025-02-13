#!/bin/bash

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

# shellcheck source=bin/common.bash
source "${here}/inventory-parser.bash"

# shellcheck disable=SC2154
if [ -e "${config[groups_inventory_file]}" ]; then
  log_info_no_newline "${config[groups_inventory_file]} will be overwritten, Proceed [y/N] ? "
  read -n 1 -r reply
  if [[ "${reply,,}" != "y" ]]; then
    exit 1
  fi
fi

if [[ "$(group_exists "${config[inventory_file]}" all)" == "true" ]]; then
  all_section="$(get_section "${config[inventory_file]}" all)"
  echo -e "$all_section\n" >"${config[groups_inventory_file]}"
else
  log_error "Error: [all] group is not defined in ${config[inventory_file]}"
  exit 1
fi

if [[ "$(group_exists "${config[inventory_file]}" kube_control_plane)" == "true" ]]; then
  kube_control_plane="$(get_section "${config[inventory_file]}" kube_control_plane)"
  echo -e "$kube_control_plane\n" >>"${config[groups_inventory_file]}"
else
  log_error "Error: [kube_control_plane] group is not defined in ${config[inventory_file]}"
  exit 1
fi

if [[ "$(group_exists "${config[inventory_file]}" etcd)" == "true" ]]; then
  etcd_section="$(get_section "${config[inventory_file]}" etcd)"
  echo -e "$etcd_section\n" >>"${config[groups_inventory_file]}"
else
  log_error "Error: [etcd] group is not defined in ${config[inventory_file]}"
  exit 1
fi

if [[ "$(group_exists "${config[inventory_file]}" kube_node)" == "true" ]]; then
  kube_node_section="$(get_section "${config[inventory_file]}" kube_node)"
  echo -e "$kube_node_section\n" >>"${config[groups_inventory_file]}"
else
  log_error "Error: [kube_node] group is not defined in ${config[inventory_file]}"
  exit 1
fi

# shellcheck disable=SC2091
if [[ "$(group_exists "${config[inventory_file]}" k8s_cluster)" == "true" ]]; then
  if $(group_has_children "${config[inventory_file]}" k8s_cluster); then
    k8s_cluster_children="$(get_group_children "${config[inventory_file]}" k8s_cluster)"
    add_group "${config[groups_inventory_file]}" "k8s_cluster:children"
    echo -e "$k8s_cluster_children" >>"${config[groups_inventory_file]}"
  else
    k8s_cluster_section="$(get_section "${config[inventory_file]}" k8s_cluster)"
    echo -e "$k8s_cluster_section\n" >>"${config[groups_inventory_file]}"
  fi
else
  log_error "Error: [k8s_cluster:children] group is not defined in ${config[inventory_file]}"
fi

# shellcheck disable=SC2154
nodes=$(ops_kubectl "$prefix" get nodes -o=jsonpath='{.items[*].metadata.name}')

for node in $nodes; do
  assign_host "$node"
done
