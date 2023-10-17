#!/bin/bash

# This script will run an ansible playbook.
# It's not to be executed on its own but rather via `ck8s-kubespray reboot-nodes <wc|sc>`.
# Add the variable "manual_prompt = true" for a manual prompt.
# The script may fail and in such situations rerun the script.

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

log_info "Running playbook reboot_nodes"
pushd "${here}/../playbooks"

ansible-playbook -i "${config[inventory_file]}" reboot_nodes.yml -b "$@"

popd

log_info "Playbook ran successfully!"
