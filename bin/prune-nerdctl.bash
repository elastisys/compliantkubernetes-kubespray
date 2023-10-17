#!/bin/bash

# This script will run an ansible playbook.
# It's not to be executed on its own but rather via `ck8s-kubespray prune-nerdctl <wc|sc>`.

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

log_info "Running playbook prune_nerdctl"
pushd "${here}/../playbooks"

ansible-playbook -i "${config[inventory_file]}" prune_nerdctl.yml -b "$@"

popd

log_info "Playbook ran successfully!"
