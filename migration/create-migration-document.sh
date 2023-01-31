#!/bin/bash

set -euo pipefail

usage() {
    echo "This script must have ck8s-kubespray old and new versions as arguments including patch versions."
    echo "If patch version does not matter for this migration then replace it with x. The second argument should include the full new version."
    echo "Usage: $0 [old_version] [new_version]"
    echo "Example: ./create-migration-document.sh v2.30.x-ck8sx v2.31.x-ck8s1"
    echo "or: ./create-migration-document.sh v2.30.1-ck8s1 v2.30.1-ck8s2"
}
if [  $# -lt 2 ]; then
    usage
    exit 1
fi

here="$(dirname "$(readlink -f "$0")")"
export old_version="${1}"
export new_version="${2}"

echo "You are about to create the migration documentation for versions"
echo "  from: ${old_version}"
echo "  to:   ${new_version}"
echo -n "Are you sure you want to continue [y/N]: "
read -r reply
if [[ ! "${reply}" =~ ^[yY]$ ]]; then
  echo "Aborting..."
  exit 0
fi

folder_name="${here}/${old_version}-${new_version}"

if [ -d "${folder_name}" ]; then
    echo "- ${folder_name} directory exists"
else
    mkdir "${folder_name}"
    echo "- ${folder_name} directory created"
fi

if [ -f "${folder_name}/upgrade-cluster.md" ]; then
    echo -n "- ${folder_name}/upgrade-cluster.md exists. Do you want to replace it? (y/N): "
    read -r reply
    if [[ ${reply} =~ ^[yY]$ ]]; then
        envsubst < "${here}/template/upgrade-cluster.md" > "${folder_name}/upgrade-cluster.md"
        echo "- ${folder_name}/upgrade-cluster.md replaced"
    fi
else
    envsubst < "${here}/template/upgrade-cluster.md" > "${folder_name}/upgrade-cluster.md"
    echo "- ${folder_name}/upgrade-cluster.md created"
fi
