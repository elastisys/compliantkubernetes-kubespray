#!/bin/bash

# This script will generate a dynamic inventory based on the
# node-labels-and-taints.yaml config file. The dynamic inventory is then used
# to apply node labels and taints when applying.

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

usage() {
  echo "Usage: ${0} [--list] [--host <hostname>]" >&2
  exit 1
}

[ "${#}" -ge 1 ] || usage

if [ ! -f "${config["node_labels_and_taints"]}" ]; then
  echo '{}'
  exit
fi

declare -a identifiers

readarray -t identifiers <<<"$(yq -r 'keys | .[]' "${config["node_labels_and_taints"]}")"

inventory="$(ansible-inventory -i "${config[inventory_file]}" --list)"

inventory_yaml() {
  for identifier in "${identifiers[@]}"; do
    echo "node-label-and-taints-${identifier}:"
    echo "  hosts:"
    echo "${inventory}" | yq --input-format json --output-format yaml '[.k8s_cluster.hosts[] | select(test("'"${identifier}"'"))]' | sed 's/^/    /'
    echo "  vars:"
    yq ".${identifier}" "${config["node_labels_and_taints"]}" | sed 's/^/    /'
  done
}

case "${1}" in
"--list")
  inventory_yaml | yq -o json
  ;;
"--host")
  echo '{}'
  ;;
*)
  usage
  ;;
esac
