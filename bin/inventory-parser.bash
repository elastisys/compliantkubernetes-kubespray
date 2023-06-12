#!/bin/bash

set -e -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

# Cache hosts info
output_hosts_info(){
  local filename="$1"
  # shellcheck disable=SC2016
  cluster_path=$(dirname "${filename}")
  if [[ -f "${cluster_path}/terraform.tfstate" ]]; then
    checksum=$(cat "${cluster_path}/terraform.tfstate" "${filename}" | md5sum | awk '{print $1}')
  else
    checksum=$(md5sum "${filename}" | awk '{print $1}')
  fi
  if ! [[ -f "/tmp/${checksum}.cache" ]]; then
    ansible-inventory -i "${filename}" --list --output "/tmp/${checksum}.cache"
  fi
  cat "/tmp/${checksum}.cache"
}

# Get inventory groups
# Args: <inventory>
read_inventory_groups(){
  local filename="$1"
  output_hosts_info "${filename}" | jq -r ". | keys[] | select(. != \"_meta\")"
}

# Get the hosts of a specific group
# Args: <inventory> <group>
get_group_hosts() {
  local filename="$1"
  local section="$2"
  hosts=()

  # shellcheck disable=SC2091
  if [[ ${section} == "all" ]]; then
    readarray -td '' hosts < <(output_hosts_info "${filename}" |  jq -r "._meta.hostvars | keys[]")
  elif $(output_hosts_info "${filename}"| jq ".$section | has(\"hosts\")"); then
    readarray -td '' hosts < <(output_hosts_info "${filename}" | jq -r ".$section.hosts[]")
  fi

  echo "${hosts[@]}"
}

# Check if group has children
# Args: <inventory> <group>
group_has_children() {
  local filename="$1"
  local section="$2"

  # shellcheck disable=SC2091
  if $(output_hosts_info "${filename}"| jq ".$section | has(\"children\")" ); then
    echo true; return ;
  fi

  echo "false";
}

# Get the children of a specific group
# Args: <inventory> <group>
get_group_children() {
  local filename="$1"
  local section="$2"
  hosts=()

  # shellcheck disable=SC2091
  if $(output_hosts_info "${filename}"| jq ".$section | has(\"children\")" ); then
    readarray -td '' hosts < <(output_hosts_info "${filename}"| jq -r ".$section.children[]")
  fi

  echo "${hosts[@]}"
}

# Get all hosts
# Args: <inventory>
get_all_hosts() {
  local filename="$1"
  readarray -td '' all < <(output_hosts_info "${filename}"| jq -r "._meta.hostvars | keys[]")

  echo "${all[@]}"
}


# Get the full section of a group
# Args: <inventory> <group>
get_section() {
  local filename="$1"
  local section="$2"
  output="[${section}]\n"
  # shellcheck disable=SC2091
  if $(output_hosts_info "${filename}"| jq ".$section | has(\"hosts\")" ); then
    output+=$(get_group_hosts "${filename}" "${section}")
  elif $(group_has_children "$filename" "${section}" ); then
    if [[ "${section}" == "all" ]]; then
      all_hosts=$(get_all_hosts "${filename}")
      variables=("ansible_user" "ansible_host" "ip" "etcd_member_name")
      for host in ${all_hosts}; do
        output+="${host}"
        for var in "${variables[@]}"; do
          if $(output_hosts_info "${filename}"| jq "._meta.hostvars[\"$host\"] | has(\"$var\")"); then
            value=$(output_hosts_info "${filename}"| jq -r "._meta.hostvars[\"$host\"].$var")
            output+=" ${var}=${value}"
          fi
        done
        if $(output_hosts_info "${filename}"| jq "._meta.hostvars[\"$host\"] | has(\"ansible_ssh_user\")"); then
          ansible_user=$(output_hosts_info "${filename}"| jq -r "._meta.hostvars[\"$host\"].ansible_ssh_user")
          output+=" ansible_user=${ansible_user}"
        fi
        output+="\n"
      done
    else
      output+=$(get_group_children "${filename}" "${section}")
    fi
  fi

  echo -ne "${output}\n"
}

# Get the value of a host variable
# Args: <inventory> <host> <var>
get_host_var() {
  local filename="$1"
  local host="$2"
  local hostvar="$3"

  output_hosts_info "${filename}"| jq -r "._meta.hostvars[\"$host\"].$hostvar"
}

# Check if host is part of a group
# Args: <inventory> <host> <group>
is_host_in_group() {
  local filename="$1"
  local host="$2"
  local group="$3"

  for h in $(get_group_hosts "${filename}" "${group}"); do
    if [[ "$host" ==  "$h" ]]; then echo "true"; return; fi
  done

  echo "false";
}

# Check if a group exists
# Args: <inventory> <group>
group_exists() {
  local filename="$1"
  local group="$2"

  groups="$(read_inventory_groups "$filename")"
  for g in $groups; do
    if [[ "$group" == "$g" ]]; then  echo "true"; return; fi
  done

  echo "false";
}

# Get a list of host variables
# Args: <inventory> <host>
get_host_vars() {
  local filename="$1"
  local host="$2"
  if [[ $(is_host_in_group "$filename" "$host" "all") == "true" ]]; then
    output_hosts_info "${filename}"| jq -r "._meta.hostvars[\"$host\"] | keys[]"
  else
    log_error "Host ${host} is not defined in the inventory"
    exit 1
  fi
}

# Set the value of a host variable, will add a new variable if doesn't exist
# Args: <inventory> <host> <variable> <value>
# NOTE: This only works for static inventories, not dynamic ones
set_host_var() {
  local filename="$1"
  local host="$2"
  local hostvar="$3"
  local value="$4"

  if [[ "${value}" == "null" ]]; then  return; fi ;

  if [[ "$(is_host_in_group "$filename" "$host" "all")" ]]; then
    awk -v target_host="$host"  -v hostvar="$hostvar"  -v val="$value" \
            -F' ' '{
                    exists=1
                    if ($1 ~ /^\[/) {
                      section=tolower(gensub(/\[(.+)\]/,"\\1",1,$1))
                      print $0
                    }
                    else if ($1 == "") print $0
                    else if ($1 !~ /^$/ && $1 !~ /^;/) {
                      gsub(/^[ \t]+|[ \t]+$/, "", $1);
                      gsub(/[\[\]]/, "", $1);
                      if (section == "all") {
                        if ($1 == target_host ){
                          for (i=2; i<=NF; i++){
                            split($i, var, "=")
                            if (var[1] == hostvar) {
                              $i=var[1]"="val
                              exists=0
                            }
                          }
                          if (exists == 1){
                            $(++NF)=hostvar"="val
                          }
                        }
                      }
                      print $0
                    }
                  }
    ' "${filename}" > /tmp/secondary-inventory.ini
    cp /tmp/secondary-inventory.ini "$filename"
    rm -rf /tmp/secondary-inventory.ini
  else
    log_error "Host $host is not defined"
  fi

}

# Remove a host variable
# Args: <inventory> <host> <variable>
# NOTE: This only works for static inventories, not dynamic ones
unset_host_var() {
  local filename="$1"
  local host="$2"
  local hostvar="$3"

  if [[ "$(is_host_in_group "$filename" "$host" "all")" ]]; then
    awk -v target_host="$host"  -v hostvar="$hostvar"  \
            -F' ' '{
                    if ($1 ~ /^\[/) {
                      section=tolower(gensub(/\[(.+)\]/,"\\1",1,$1))
                      print $0
                    }
                    else if ($1 == "") print $0
                    else if ($1 !~ /^$/ && $1 !~ /^;/) {
                      gsub(/^[ \t]+|[ \t]+$/, "", $1);
                      gsub(/[\[\]]/, "", $1);
                      if (section == "all") {
                        if ($1 == target_host ){
                          for (i=2; i<=NF; i++){
                            split($i, var, "=")
                            if (var[1] == hostvar) {
                              $i=""
                            }
                          }
                        }
                      }
                      print $0
                    }
                  }
    ' "${filename}" > /tmp/secondary-inventory.ini
    cp /tmp/secondary-inventory.ini "${filename}"
    rm -rf /tmp/secondary-inventory.ini
  else
    log_error "Host ${host} is not defined"
  fi

}

# Update the value of a host variable
# Args: <inventory> <host> <variable> <newvalue>
# NOTE: This only works for static inventories, not dynamic ones
update_host_var() {
  local filename="$1"
  local host="$2"
  local hostvar="$3"
  local value="$4"

  if [[ "$(is_host_in_group "${filename}" "${host}" all)" ]]; then
    awk -v target_host="$host"  -v hostvar="${hostvar}"  -v val="${value}" \
            -F' ' '{
                    if ($1 ~ /^\[/) {
                      section=tolower(gensub(/\[(.+)\]/,"\\1",1,$1))
                      print $0
                    }
                    else if ($1 == "") print $0
                    else if ($1 !~ /^$/ && $1 !~ /^;/) {
                      gsub(/^[ \t]+|[ \t]+$/, "", $1);
                      gsub(/[\[\]]/, "", $1);
                      if (section == "all") {
                        if ($1 == target_host ){
                          for (i=2; i<=NF; i++){
                            split($i, var, "=")
                            if (var[1] == hostvar) {
                              $i=var[1]"="val
                            }
                          }
                        }
                      }
                      print $0
                    }
                  }
    ' "${filename}" > /tmp/secondary-inventory.ini
    cp /tmp/secondary-inventory.ini "$filename"
    rm -rf /tmp/secondary-inventory.ini
  else
    log_error "Host $host is not defined"
  fi

}

# Add a new host to a group
# Args: <inventory> <host> <group>
# NOTE: This only works for static inventories, not dynamic ones
add_host_to_group() {
  local filename="$1"
  local host="$2"
  local group="$3"

  hostDefined="$(is_host_in_group "$filename" "$host" all)"
  hostExists="$(is_host_in_group "$filename" "$host" "$group")"

  if [[ "$hostDefined" == "true" || "$group" == "all" ]]; then
    if [[ "$hostExists" == "true" ]]; then
      log_warning "Host $host is already part of group $group"
    else
      sed -i "/^\[$group\]/a\\$host" "$filename"
    fi
  else
    log_error "Host $host is not defined in [all] group"
    exit 1
  fi
}

# Add to the end, a new host to a group
# Args: <inventory> <host> <group>
# NOTE: This only works for static inventories, not dynamic ones
add_host_to_group_as_last() {
  local filename="$1"
  local host="$2"
  local group="$3"

  hostDefined="$(is_host_in_group "$filename" "$host" all)"
  hostExists="$(is_host_in_group "$filename" "$host" "$group")"

  if [[ "$hostDefined" == "true" || "$group" == "all" ]]; then
    if [[ "$hostExists" == "true" ]]; then
      log_warning "Host $host is already part of group $group"
    else
      awk -v sec="[$group]" -v host="$host" 'p && $1~/\[[^]]*\]/{p=0; print host"\n"}  $1==sec{p=1} END{if (p) print host} 1' "${filename}" > /tmp/secondary-inventory.ini
      cp /tmp/secondary-inventory.ini "$filename"
    fi
  else
    log_error "Host $host is not defined in [all] group"
    exit 1
  fi
}


# Remove a host from a group
# Args: <inventory> <host> <group>
# NOTE: This only works for static inventories, not dynamic ones
remove_host_from_group() {
  local filename="$1"
  local host="$2"
  local group="$3"

  if [[ "$(is_host_in_group "$filename" "$host" "$group")" == "true" ]]; then
    awk -v target_host="$host" -v target_group="$group" \
        -F' ' '{
                global_removal=1
                if (target_group == "all") global_removal=0
                if ($1 ~ /^\[/) {
                  section=tolower(gensub(/\[(.+)\]/,"\\1",1,$1))
                  print $0
                }
                else if ($1 == "") print $0
                else if ($1 !~ /^$/ && $1 !~ /^;/) {
                  gsub(/^[ \t]+|[ \t]+$/, "", $1);
                  gsub(/[\[\]]/, "", $1);
                  if ($1 == target_host ){
                    if (global_removal == 1 && target_group != section ) {
                      print $0
                    }
                  } else {
                    print $0
                  }
                }
              }
    ' "${filename}" > /tmp/secondary-inventory.ini
    cp /tmp/secondary-inventory.ini "$filename"
  else
    log_error "Could not remove host : $host, as it is not part of the group: $group"
    exit 1
  fi
}

# Add a new group to the inventory
# Args: <inventory> <group>
# NOTE: This only works for static inventories, not dynamic ones
add_group() {
  local filename="$1"
  local group="$2"

  if [[ "$(group_exists "$filename" "$group")" == "true" ]]; then
    log_warning "Group $group already exists"
  else
    echo -e "\n\n[$group]" >> "$filename"
  fi
}
