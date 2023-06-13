#!/bin/bash

set -e -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

readInventoryGroups(){
  local filename="$1"
  gawk '{ if ($1 ~ /^\[[a-zA-Z0-9_]{1,}\]/) section=tolower(gensub(/\[(.+)\]/,"\\1",1,$1)); configuration[section]=1 } END {for (key in configuration) { print key} }' "${filename}"
}

getGroupHosts() {
  local filename="$1"
  local section="$2"

  awk -v target_group="$section" \
             -F' ' '{ 
                      if ($1 ~ /^\[[a-zA-Z0-9_]{1,}\]/)
                        section=tolower(gensub(/\[(.+)\]/,"\\1",1,$1)) 
                      else if ($1 !~ /^$/ && $1 !~ /^;/) {
                        gsub(/^[ \t]+|[ \t]+$/, "", $1); 
                        gsub(/[\[\]]/, "", $1);
                        if (section == target_group) {
                          configuration[section][$1]=""
                        }
                      } 
                    } 
                    END {
                        if ( length(configuration) > 0) {
                          for (key in configuration[target_group]) { print key }
                        } else {
                          print ""
                        }
                    }' "${filename}"
}

getSection() {
  local filename="$1"
  local section="$2"

  awk -v target_group="$section" \
            -F' ' '{ 
                    if ($1 ~ /^\[[a-zA-Z0-9_]{1,}\]/) {
                      section=tolower(gensub(/\[(.+)\]/,"\\1",1,$1))
                      if (section == target_group) print $0
                    }
                    else if ($1 !~ /^$/ && $1 !~ /^;/) {
                      if (section == target_group) {
                        print $0
                      }
                    } 
                  }' "${filename}"
}

getHostVar() {
  local filename="$1"
  local host="$2"
  local hostvar="$3"

  awk -v target_host="$host"  -v hostvar="$hostvar" \
             -F' ' '{ 
                      if ($1 ~ /^\[[a-zA-Z0-9_]{1,}\]/)
                        section=tolower(gensub(/\[(.+)\]/,"\\1",1,$1)) 
                      else if ($1 !~ /^$/ && $1 !~ /^;/) {
                        gsub(/^[ \t]+|[ \t]+$/, "", $1); 
                        gsub(/[\[\]]/, "", $1);
                        if (section == "all") {
                          if ($1 == target_host ){
                            for (i=2; i<=NF; i++){
                              split($i, var, "=")
                              if (var[1] == hostvar) {
                                value = var[2]
                              }
                            }
                          }
                        }
                      } 
                    }
                    END {
                        print value
                    }' "${filename}"
}

getHostVars() {
  local filename="$1"
  local host="$2"
  if [[ "$(isHostInGroup "$filename" "$host" "all")" == "true" ]]; then
    awk -v target_host="$host" \
              -F' ' '{ 
                        if ($1 ~ /^\[[a-zA-Z0-9_]{1,}\]/)
                          section=tolower(gensub(/\[(.+)\]/,"\\1",1,$1)) 
                        else if ($1 !~ /^$/ && $1 !~ /^;/) {
                          gsub(/^[ \t]+|[ \t]+$/, "", $1); 
                          gsub(/[\[\]]/, "", $1);
                          if (section == "all") {
                            if ($1 == target_host ){
                              for (i=2; i<=NF; i++){
                                split($i, var, "=")
                                configuration[var[1]]=""
                              }
                            }
                          }
                        } 
                      }
                      END {
                        if ( length(configuration) > 0) {
                            for (key in configuration) { print key }
                          } else {
                            print ""
                          }
                      }' "${filename}"
  else 
    log_error "Host $host is not defined"
    exit 1
  fi
}

setHostVar() {
  local filename="$1"
  local host="$2"
  local hostvar="$3"
  local value="$4"

  if [[ "$(isHostInGroup "$filename" "$host" "all")" ]]; then
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
  else
    log_error "Host $host is not defined"
  fi

}

unsetHostVar() {
  local filename="$1"
  local host="$2"
  local hostvar="$3"

  if [[ "$(isHostInGroup "$filename" "$host" "all")" ]]; then
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
    cp /tmp/secondary-inventory.ini "$filename"
  else
    log_error "Host $host is not defined"
  fi

}

updateHostVar() {
  local filename="$1"
  local host="$2"
  local hostvar="$3"
  local value="$4"

  if [[ "$(isHostInGroup $filename $host all)" ]]; then
    awk -v target_host="$host"  -v hostvar="$hostvar"  -v val="$value" \
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
  else
    log_error "Host $host is not defined"
  fi

}

isHostInGroup() {
  local filename="$1"
  local host="$2"
  local group="$3"

  hosts="$(getGroupHosts $filename $group)"
  for h in $hosts; do 
    if [[ "$host" ==  "$h" ]]; then echo "true"; break; fi 
  done
}

groupExists() {
  local filename="$1"
  local group="$2"

  groups="$(readInventoryGroups $filename)"
  for g in $groups; do
    if [[ "$group" == "$g" ]]; then  echo "true"; break; fi
  done  
  
}

addHostToGroup() {
  local filename="$1"
  local host="$2"
  local group="$3"

  hostDefined="$(isHostInGroup $filename $host all)"
  hostExists="$(isHostInGroup $filename $host $group)"

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

removeHostFromGroup() {
  local filename="$1"
  local host="$2"
  local group="$3" 

  if [[ "$(isHostInGroup $filename $host all)" == "true" ]]; then
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
    log_error "Host $host is not defined"
    exit 1
  fi
}

addGroup() {
  local filename="$1"
  local group="$2"

  if [[ "$(groupExists $filename $group)" == "true" ]]; then 
    log_warning "Group $group already exists"
  else
    echo -e "\n\n[$group]" >> "$filename"
  fi
}