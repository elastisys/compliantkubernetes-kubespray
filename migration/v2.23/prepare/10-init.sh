#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

yq_add sc all/ck8s-kubespray-general .ck8sKubesprayVersion "\"$(git_version)\""
yq_add wc all/ck8s-kubespray-general .ck8sKubesprayVersion "\"$(git_version)\""
