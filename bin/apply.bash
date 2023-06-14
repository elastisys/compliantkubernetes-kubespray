#!/bin/bash

# This script will create a kubernetes cluster using kubespray.
# It will also install some python dependencies for kubespray in a virtual environment
# It's not to be executed on its own but rather via `ck8s-kubespray apply <prefix>`.

set -eu -o pipefail
shopt -s globstar nullglob dotglob

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"
ck8s_kubespray_version_check
kubespray_version_check
check_openstack_credentials

log_info "Creating kubernetes cluster using kubespray"
pushd "${kubespray_path}"

if [ -z "${CK8S_KUBESPRAY_NO_VENV+x}" ]; then
    log_info "Installing requirements for kubespray"
    python3 -m venv venv
    # shellcheck disable=SC1091
    source venv/bin/activate
    pip install -r requirements.txt
fi

log_info "Running kubespray"
ansible-playbook -i "${config[inventory_file]}" cluster.yml -b "${@}"

log_info "Kubespray done"

log_info "Get kubeconfig"
ansible-playbook -i "${config[inventory_file]}" ../playbooks/kubeconfig.yml -b
log_info "Adding cluster-admin ClusterRoleBinding"
ansible-playbook -i "${config[inventory_file]}" ../playbooks/cluster_admin_rbac.yml -b

popd

log_info "Cluster created successfully!"
