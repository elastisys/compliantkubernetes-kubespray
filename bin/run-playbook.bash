#!/bin/bash

# This script will run an ansible playbook available in kubespray.
# It will also install some python dependencies for kubespray in a virtual environment
# It's not to be executed on its own but rather via `ck8s-kubespray run-playbook <prefix> <playbook>`.

set -eu -o pipefail
shopt -s globstar nullglob dotglob

if [ $# -lt 1 ]; then
    echo "error when running $0: argument mismatch" 1>&2
    exit 1
fi

playbook=$1
shift 1

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=common.bash
source "${here}/common.bash"

log_info "Running kubespray playbook ${playbook}"
pushd "${kubespray_path}"

log_info "Installing requirements for kubespray"
python3 -m venv venv
# shellcheck source=../kubespray/venv/bin/activate
source venv/bin/activate
pip install -r requirements.txt

log_info "Running kubespray"
sops_exec_file_no_fifo "${secrets[ssh_key]}" "ansible-playbook -i ${config[inventory_file]} ${playbook} -b --private-key {} ${*}"

popd

log_info "Kubespray done"

if [ -f "${config_path}/artifacts/admin.conf" ]; then
    mv "${config_path}/artifacts/admin.conf" "${secrets[kube_config]}"
    sops_encrypt "${secrets[kube_config]}"
fi

log_info "Playbook ${playbook} ran sucessfully!"
log_info "Kubeconfig located at ${secrets[kube_config]}"
