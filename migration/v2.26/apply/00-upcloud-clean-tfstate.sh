#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
    log_info "Removing old tfstate from service cluster"
    terraform state rm -state="${CK8S_CONFIG_PATH}/sc-config/terraform.tfstate" null_resource.inventories
    terraform state rm -state="${CK8S_CONFIG_PATH}/sc-config/terraform.tfstate" data.template_file.inventory
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
    log_info "Removing old tfstate from workload cluster"
    terraform state rm -state="${CK8S_CONFIG_PATH}/wc-config/terraform.tfstate" null_resource.inventories
    terraform state rm -state="${CK8S_CONFIG_PATH}/wc-config/terraform.tfstate" data.template_file.inventory
fi
