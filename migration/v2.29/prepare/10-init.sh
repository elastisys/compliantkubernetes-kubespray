#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  yq_add sc all/ck8s-kubespray-general .ck8sKubesprayVersion "\"$(git_version)\""
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  yq_add wc all/ck8s-kubespray-general .ck8sKubesprayVersion "\"$(git_version)\""
fi
