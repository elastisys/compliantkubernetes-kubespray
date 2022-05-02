#!/bin/bash

# This script will run the remove-node.yml playbook.
# It will also install some python dependencies for kubespray in a virtual environment
# It's not to be executed on its own but rather via `ck8s-kubespray remove-node <prefix> <node_name>` [<options>].

set -eu -o pipefail
shopt -s globstar nullglob dotglob

if [ $# -lt 1 ]; then
    echo "error when running $0: argument mismatch" 1>&2
    exit 1
fi

playbook=remove-node.yml
node_name=$1
shift 1

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

check_openstack_credentials

pushd "${kubespray_path}"

if [ -z "${CK8S_KUBESPRAY_NO_VENV+x}" ]; then
    log_info "Installing requirements for kubespray"
    python3 -m venv venv
    # shellcheck disable=SC1091
    source venv/bin/activate
    pip install -r requirements.txt
fi

log_info "Remvoing node: $node_name"

# shellcheck disable=SC2145
log_info Executing \"ansible-playbook -i "${config[inventory_file]}" "${playbook}" -b --extra-vars="node=${node_name}" "${@}"\"

ansible-playbook -i "${config[inventory_file]}" "${playbook}" -b --extra-vars="node=${node_name}" "${@}"

popd

log_info "Kubespray done - playbook ${playbook} ran sucessfully!"
