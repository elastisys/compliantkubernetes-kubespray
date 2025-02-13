#!/bin/bash

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

# shellcheck source=bin/common.bash
source "${here}/inventory-parser.bash"

log_info "Inventories sync in process .."

# shellcheck disable=SC2154
# shellcheck disable=SC2091
# shellcheck disable=SC2046
for host in $(get_group_hosts "${config[groups_inventory_file]}" all); do
  echo "checking $host"
  if $(! contains_element "$host" $(get_group_hosts "${config[inventory_file]}" all)); then
    log_info "Removing $host from groups inventory.."
    remove_host_from_group "${config[groups_inventory_file]}" "$host" all
  fi
done

# shellcheck disable=SC2091
# shellcheck disable=SC2046
for host in $(get_group_hosts "${config[inventory_file]}" all); do
  if $(! contains_element "$host" $(get_group_hosts "${config[groups_inventory_file]}" all)); then
    log_info "Adding $host to groups inventory.."
    add_host_to_group_as_last "${config[groups_inventory_file]}" "$host" "all"
    hostvars=("ansible_user" "ansible_host" "ip" "etcd_member_name")
    log_info "Syncing hostvars for new host: $host .."
    for hostvar in "${hostvars[@]}"; do
      if [[ "${hostvar}" == "ansible_user" ]]; then
        if $(output_hosts_info "${config[inventory_file]}" | jq "._meta.hostvars[\"$host\"] | has(\"ansible_ssh_user\")"); then
          value=$(get_host_var "${config[inventory_file]}" "$host" "ansible_ssh_user")
        else
          value=$(get_host_var "${config[inventory_file]}" "$host" "$hostvar")
        fi
      else
        value=$(get_host_var "${config[inventory_file]}" "$host" "$hostvar")
      fi
      log_info "Setting $hostvar to $value for $host"
      set_host_var "${config[groups_inventory_file]}" "$host" "$hostvar" "$value"
    done
    assign_host "$host"
  fi
done

# shellcheck disable=SC2091
for host in $(get_group_hosts "${config[groups_inventory_file]}" all); do
  hostvars=("ansible_user" "ansible_host" "ip" "etcd_member_name")
  log_info "Syncing hostvars for existing host: $host"
  for hostvar in "${hostvars[@]}"; do
    if [[ "${hostvar}" == "ansible_user" ]]; then
      if $(output_hosts_info "${config[inventory_file]}" | jq "._meta.hostvars[\"$host\"] | has(\"ansible_ssh_user\")"); then
        value=$(get_host_var "${config[inventory_file]}" "$host" "ansible_ssh_user")
      else
        value=$(get_host_var "${config[inventory_file]}" "$host" "$hostvar")
      fi
    else
      value=$(get_host_var "${config[inventory_file]}" "$host" "$hostvar")
    fi
    update_host_var "${config[groups_inventory_file]}" "$host" "$hostvar" "$value"
  done
done
