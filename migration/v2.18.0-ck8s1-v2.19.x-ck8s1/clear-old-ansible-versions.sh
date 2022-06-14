#!/bin/bash

here="$(dirname "$(readlink -f "$0")")"

pushd "${here}/../../kubespray" || return

python3 -m venv venv
# shellcheck source=/dev/null
source venv/bin/activate

pip uninstall ansible -y
pip uninstall ansible-base -y
pip uninstall ansible-core -y
pip uninstall wheel -y

deactivate
popd || return
