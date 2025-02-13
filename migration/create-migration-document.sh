#!/bin/bash

set -euo pipefail

usage() {
  echo "This script must have ck8s-kubespray old and new versions as arguments."
  echo "For the version arguments, you only need to include as much information as is necessary; for minor versions include major/minor version, for patch versions include major/minor/patch version, etc."
  echo "Usage: $0 [old_version] [new_version]"
  echo "Example: ./create-migration-document.sh v2.30 v2.31"
  echo "or: ./create-migration-document.sh v2.30.1-ck8s1 v2.30.1-ck8s2"
}
if [ $# -lt 2 ]; then
  usage
  exit 1
fi

here="$(dirname "$(readlink -f "$0")")"
export old_version="${1}"
export new_version="${2}"
folder_name="${here}/${new_version}"

echo "You are about to create the migration documentation for versions"
echo "  from: ${old_version}"
echo "  to:   ${new_version}"
echo -n "Are you sure you want to continue [y/N]: "
read -r reply
if [[ ! "${reply}" =~ ^[yY]$ ]]; then
  echo "Aborting..."
  exit 0
fi

export full_version="${new_version}"

if [[ "${full_version}" =~ ^v[0-9]+\.[0-9]+$ ]]; then
  full_version="${full_version}.x"
fi

if [[ "${full_version}" =~ ^v[0-9]+\.[0-9]+\.[0-9x]+$ ]]; then
  full_version="${full_version}-ck8sx"
fi

if [ -d "${folder_name}" ]; then
  echo "- ${folder_name} directory exists"
else
  mkdir "${folder_name}"
  echo "- ${folder_name} directory created"
fi

if [ -f "${folder_name}/README.md" ]; then
  echo -n "- ${folder_name}/README.md exists. Do you want to replace it? (y/N): "
  read -r reply
  if [[ ${reply} =~ ^[yY]$ ]]; then
    envsubst <"${here}/template/README.md" >"${folder_name}/README.md"
    echo "- ${folder_name}/README.md replaced"
  fi
else
  envsubst <"${here}/template/README.md" >"${folder_name}/README.md"
  echo "- ${folder_name}/README.md created"
fi

cp -r "${here}/template/prepare" "${folder_name}/"
mkdir -p "${folder_name}/apply"
