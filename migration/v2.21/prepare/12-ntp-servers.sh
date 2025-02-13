#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

set_ntp_servers=false
log_info "If your environment is hosted in Sweden, NTP servers can be set automatically."
log_info "If your environment is not hosted in Sweden, set ntp_servers in group_vars/k8s_cluster/ck8s-k8s-cluster.yaml manually after the prepare script finishes."
log_info_no_newline "Is your environment hosted in Sweden? [y/N]: "
read -r reply
if [[ "${reply}" == "y" ]]; then
  set_ntp_servers=true
fi

yq_add sc k8s_cluster/ck8s-k8s-cluster .ntp_enabled true
yq_add sc k8s_cluster/ck8s-k8s-cluster .ntp_manage_config true
if [[ "${set_ntp_servers}" == true ]]; then
  yq_add sc k8s_cluster/ck8s-k8s-cluster .ntp_servers '[ "gbg1.ntp.netnod.se iburst", "gbg2.ntp.netnod.se iburst", "lul1.ntp.netnod.se iburst", "lul2.ntp.netnod.se iburst", "mmo1.ntp.netnod.se iburst", "mmo2.ntp.netnod.se iburst", "sth1.ntp.netnod.se iburst", "sth2.ntp.netnod.se iburst", "sth3.ntp.netnod.se iburst", "sth4.ntp.netnod.se iburst", "svl1.ntp.netnod.se iburst", "svl2.ntp.netnod.se iburst"]'
else
  yq_add sc k8s_cluster/ck8s-k8s-cluster .ntp_servers '[]'
fi
yq_add sc k8s_cluster/ck8s-k8s-cluster .ntp_timezone "\"Etc/UTC\""

yq_add wc k8s_cluster/ck8s-k8s-cluster .ntp_enabled true
yq_add wc k8s_cluster/ck8s-k8s-cluster .ntp_manage_config true
if [[ "${set_ntp_servers}" == true ]]; then
  yq_add wc k8s_cluster/ck8s-k8s-cluster .ntp_servers '[ "gbg1.ntp.netnod.se iburst", "gbg2.ntp.netnod.se iburst", "lul1.ntp.netnod.se iburst", "lul2.ntp.netnod.se iburst", "mmo1.ntp.netnod.se iburst", "mmo2.ntp.netnod.se iburst", "sth1.ntp.netnod.se iburst", "sth2.ntp.netnod.se iburst", "sth3.ntp.netnod.se iburst", "sth4.ntp.netnod.se iburst", "svl1.ntp.netnod.se iburst", "svl2.ntp.netnod.se iburst"]'
else
  yq_add wc k8s_cluster/ck8s-k8s-cluster .ntp_servers '[]'
fi
yq_add wc k8s_cluster/ck8s-k8s-cluster .ntp_timezone "\"Etc/UTC\""
