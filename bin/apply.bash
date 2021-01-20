#!/bin/bash

# This script will create a kubernetes cluster using kubespray.
# It will also install some python dependencies for kubespray in a virtual environment
# It's not to be executed on its own but rather via `ck8s-kubespray apply <prefix>`.

set -eu -o pipefail
shopt -s globstar nullglob dotglob

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=common.bash
source "${here}/common.bash"

log_info "Creating kubernetes cluster using kubespray"
# shellcheck disable=SC2154
pushd "${kubespray_path}"

log_info "Installing requirements for kubespray"
python3 -m venv venv
# shellcheck source=../kubespray/venv/bin/activate
source venv/bin/activate
pip install -r requirements.txt

log_info "Running kubespray"
sops_exec_file_no_fifo "${secrets[ssh_key]}" "ansible-playbook -i \"${config[inventory_file]}\" cluster.yml -b --private-key {} ${*}"

popd

log_info "Kubespray done"

if [ -f "${config_path}/artifacts/admin.conf" ]; then
    mv "${config_path}/artifacts/admin.conf" "${secrets[kube_config]}"
    sops_encrypt "${secrets[kube_config]}"
fi

log_info "Cluster created sucessfully!"
log_info "Kubeconfig located at ${secrets[kube_config]}"
