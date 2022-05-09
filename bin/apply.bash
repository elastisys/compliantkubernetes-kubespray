#!/bin/bash

# This script will create a kubernetes cluster using kubespray.
# It will also install some python dependencies for kubespray in a virtual environment
# It's not to be executed on its own but rather via `ck8s-kubespray apply <prefix>`.

set -eu -o pipefail
shopt -s globstar nullglob dotglob

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

check_openstack_credentials

log_info "Creating kubernetes cluster using kubespray"
pushd "${kubespray_path}"

VENV_NAME="$(pwgen 5 1)"

if [ -z "${CK8S_KUBESPRAY_NO_VENV+x}" ]; then
    log_info "Installing requirements for kubespray"
    python3 -m venv "venv-${VENV_NAME}"
    # shellcheck disable=SC1091
    source "venv-${VENV_NAME}/bin/activate"
    pip install -r requirements.txt
fi

log_info "Running kubespray"
ansible-playbook -i "${config[inventory_file]}" cluster.yml -b "${@}"

popd

log_info "Kubespray done"

if [ -f "${config_path}/artifacts/admin.conf" ]; then
    mkdir -p "${state_path}"
    mv "${config_path}/artifacts/admin.conf" "${secrets[kube_config]}"
    sops_encrypt "${secrets[kube_config]}"
fi

rm -r "${kubespray_path}/venv-${VENV_NAME}"

log_info "Cluster created sucessfully!"
log_info "Kubeconfig located at ${secrets[kube_config]}"
