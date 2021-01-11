#!/bin/bash

# This script takes care of initializing a CK8S configuration path for kubespray.
# It writes the default configuration files to the config path and generates
# some defaults where applicable.
# It's not to be executed on its own but rather via `ck8s-kubespray init ...`.

set -eu -o pipefail
shopt -s globstar nullglob dotglob

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "error when running $0: argument mismatch" 1>&2
    exit 1
fi

flavor=$1
ssh_key_file=$2
if [ $# -eq 3 ]; then
    fingerprint=$3
fi

here="$(dirname "$(readlink -f "$0")")"
source "${here}/common.bash"

CK8S_CLOUD_PROVIDER=${CK8S_CLOUD_PROVIDER:-""}
if [[ ${CK8S_CLOUD_PROVIDER} != "" ]]; then
    log_error "ERROR: CK8S_CLOUD_PROVIDER is not supported"
    exit 1
fi

# Validate the flavor
if [ "${flavor}" != "default" ]; then
    log_error "ERROR: Unsupported flavor: ${flavor}"
    exit 1
fi

generate_sops_config() {
    if [ -z ${fingerprint+x} ]; then
        if [ -z ${CK8S_PGP_FP+x} ]; then
            log_error "ERROR: either the <SOPS fingerprint> argument or the env variable CK8S_PGP_FP must be set."
            exit 1
        else
            fingerprint="${CK8S_PGP_FP}"
        fi
    fi
    log_info "Initializing SOPS config with PGP fingerprint: ${fingerprint}"
    sops_config_write_fingerprints "${fingerprint}"
}

process_file() {
    if [[ $# -ne 1 ]]; then
        log_error "ERROR: number of args in process_file must be 1. #=[$#]"
        exit 1
    fi

    default_file=${1}

    relative_file_path=${default_file#${config_defaults_path}}
    file="${config_path}/${relative_file_path}"

    touch "${file}"
    yq merge --inplace "${file}" "${default_file}"
}


process_dir() {
    if [[ $# -ne 2 ]]; then
        log_error "ERROR: number of args in process_dir must be 2. #=[$#]"
        exit 1
    fi

    dir=${1}
    out_name=${2}
    out_file=${out_name}.yml
    relative_file_path=${dir#${config_defaults_path}}
    out_file_path="${config_path}/${relative_file_path}"

    tmpfile=$(mktemp -p /tmp ck8s-kubespray.XXXXXXXXXX)
    append_trap "rm $tmpfile" EXIT

    flavorfile=${config_defaults_path}/flavors/${out_name}-${flavor}.yml

    for file in "${dir}"/*.yml; do
        cat "${file}" >> "${tmpfile}"
    done

    if [[ -f "${flavorfile}" ]]; then
        # merging temp with flavor
        yq merge --inplace -a=overwrite --overwrite "${tmpfile}" "${flavorfile}"
    fi

    # merge temp file with the config
    if [[ -f "${out_file_path}/${out_file}" ]]; then
        yq merge "$tmpfile" "${out_file_path}/${out_file}" --inplace -a=overwrite --overwrite --prettyPrint
    fi
    cat "$tmpfile" > "${out_file_path}/${out_file}"
}

generate_base_kubespray_config() {
    #create the kubespray conf dirs
    mkdir -p "${config_path}"
    mkdir -p "${config_path}/group_vars/all"
    mkdir -p "${config_path}/group_vars/k8s-cluster"

    # Copy inventory.ini
    if [[ ! -f "${config[inventory_file]}" ]]; then
      PREFIX=${prefix} envsubst > "${config[inventory_file]}" < "${config_defaults_path}/inventory.ini"
    else
      log_info "Inventory already exists, leaving it as it is"
    fi

    #merge etcd.yml
    process_file "${config_defaults_path}/group_vars/etcd.yml"

    #process group_vars/all
    process_dir "${config_defaults_path}/group_vars/all" all

    #process group_vars/k8s-cluster
    process_dir "${config_defaults_path}/group_vars/k8s-cluster" k8s-cluster
}

copy_ssh_file() {
    if [ -f "${secrets[ssh_key]}" ]; then
        log_info "SSH key already exists: ${secrets[ssh_key]}"
    else
        mkdir -p "${ssh_folder}"
        cp "${ssh_key_file}" "${secrets[ssh_key]}"
        sops_encrypt "${secrets[ssh_key]}"
    fi
}

create_infra_file() {
    #TODO this file should be removed
    mkdir -p "${state_path}"
    touch "${config[infrastructure_file]}"
}

log_info "Initializing CK8S configuration with flavor: ${flavor}"

if [ -f "${sops_config}" ]; then
    log_info "SOPS config already exists: ${sops_config}"
    validate_sops_config
else
    generate_sops_config
fi

generate_base_kubespray_config

copy_ssh_file

create_infra_file

log_info "Config initialized"

log_info "Time to edit the following files:"
log_info "${config[inventory_file]}"
