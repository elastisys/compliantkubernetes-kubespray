#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_GITHUB_TOKEN:?Missing CK8S_GITHUB_TOKEN}"

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]:-"${0}"}")")"

repo="elastisys/welkin-apps"

api="https://api.github.com/repos/${repo}"

raw="https://raw.githubusercontent.com/${repo}"

req() {
  curl \
    --fail \
    --header "Authorization: Bearer ${CK8S_GITHUB_TOKEN}" \
    --show-error \
    --silent \
    "${@}"
}

latest_release() {
  req "${api}/releases" |
    jq -r '.[].tag_name' |
    sort --version-sort --reverse |
    head --lines 1
}

fetch() {
  tag="${1}"
  source="${2}"
  target="${3}"

  req --location "${raw}/refs/tags/${tag}/${source}" --output "${target}"
}

main() {
  tag="$(latest_release)"

  fetch "${tag}" \
    helmfile.d/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml \
    "${here}/crd-servicemonitors.yaml"
}

main "${@}"
