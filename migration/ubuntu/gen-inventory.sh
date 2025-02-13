#!/usr/bin/env bash

set -eu

: "${CK8S_CONFIG_PATH:?"CK8S_CONFIG_PATH is unset"}"

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <sc|wc>"
  exit 1
fi

if [[ "$1" =~ (sc|wc) ]]; then
  source="$CK8S_CONFIG_PATH/$1-config/terraform.tfstate"
  target="$CK8S_CONFIG_PATH/$1-config/inventory.ini"
else
  echo "usage: $0 <sc|wc>"
  exit 1
fi

get_ctl() {
  yq4 -oj '[.resources[] | select(.type == "openstack_compute_instance_v2" and (.name == "k8s_master" or .name == "k8s_masters")) .instances[]]' "$source"
}

get_srv() {
  yq4 -oj '[.resources[] | select(.type == "openstack_compute_instance_v2" and (.name == "k8s_node" or .name == "k8s_nodes")) | .instances[]]' "$source"
}

get_fip() {
  yq4 -oj '[.resources[] | select(.type == "openstack_networking_floatingip_associate_v2") | .instances[]]' "$source"
}

find_key() {
  yq4 -oj '.[].index_key'
}

filter_key() {
  yq4 -oj ".[] | select(.index_key == $1)"
}

find_access() {
  yq4 -P '.attributes.access_ip_v4'
}

find_name() {
  yq4 -P '.attributes.name'
}

find_priv() {
  yq4 -P '.attributes.fixed_ip'
}

find_pub() {
  yq4 -P '.attributes.floating_ip'
}

declare -a ctl
declare -a srv

declare -A ctl_name
declare -A ctl_priv
declare -A ctl_pub

declare -A srv_name
declare -A srv_priv
declare -A srv_pub

mapfile -t ctl < <(get_ctl | find_key)
mapfile -t srv < <(get_srv | find_key)

for node in "${ctl[@]}"; do
  ctl_name["$node"]="$(get_ctl | filter_key "$node" | find_name)"

  if [ -z "$(get_fip | filter_key "$node")" ]; then
    ctl_priv["$node"]="$(get_ctl | filter_key "$node" | find_access)"
    ctl_pub["$node"]="$(get_ctl | filter_key "$node" | find_access)"
  else
    ctl_priv["$node"]="$(get_fip | filter_key "$node" | find_priv)"
    ctl_pub["$node"]="$(get_fip | filter_key "$node" | find_pub)"
  fi
done

for node in "${srv[@]}"; do
  srv_name["$node"]="$(get_srv | filter_key "$node" | find_name)"

  if [ -z "$(get_fip | filter_key "$node")" ]; then
    srv_priv["$node"]="$(get_srv | filter_key "$node" | find_access)"
    srv_pub["$node"]="$(get_srv | filter_key "$node" | find_access)"
  else
    srv_priv["$node"]="$(get_fip | filter_key "$node" | find_priv)"
    srv_pub["$node"]="$(get_fip | filter_key "$node" | find_pub)"
  fi
done

echo "
[all]
$(for key in "${ctl[@]}"; do echo "${ctl_name["$key"]} ansible_user=ubuntu ansible_host=${ctl_pub["$key"]} ip=${ctl_priv["$key"]} etcd_member=${ctl_name["$key"]}"; done)
$(for key in "${srv[@]}"; do echo "${srv_name["$key"]} ansible_user=ubuntu ansible_host=${srv_pub["$key"]} ip=${srv_priv["$key"]}"; done)

[kube_control_plane]
$(for key in "${ctl[@]}"; do echo "${ctl_name["$key"]}"; done)

[etcd]
$(for key in "${ctl[@]}"; do echo "${ctl_name["$key"]}"; done)

[kube_node]
$(for key in "${srv[@]}"; do echo "${srv_name["$key"]}"; done)

[k8s_cluster:children]
kube_control_plane
kube_node
" >"$target"
