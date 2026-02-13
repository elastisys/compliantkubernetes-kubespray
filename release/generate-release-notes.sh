#!/usr/bin/env bash

set -euo pipefail

if ! command -v releaser >/dev/null; then
  echo "releaser is not installed, install it by running: go install github.com/elastisys/releaser/cmd/releaser@latest" >&2
  echo "For more information see https://github.com/elastisys/releaser/#installation" >&2
  exit 1
fi

: "${CK8S_GITHUB_TOKEN:?Missing CK8S_GITHUB_TOKEN}"

function usage() {
  echo "Usage: ${0} VERSION" >&2
  exit 1
}

[ ${#} -eq 1 ] || usage

releaser changelog compliantkubernetes-kubespray "${1}" --output release-notes
