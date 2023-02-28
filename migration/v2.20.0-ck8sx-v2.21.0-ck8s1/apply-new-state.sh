#!/bin/bash
# shellcheck disable=SC2002

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
: "${OS_USERNAME:?Missing OS_USERNAME}"
: "${OS_PASSWORD:?Missing OS_PASSWORD}"

here="$(dirname "$(readlink -f "$0")")"
openstack_terraform_dir="${here}/../../kubespray/contrib/terraform/openstack"

# shellcheck disable=SC1090
source "${CK8S_CONFIG_PATH}/openrc.sh"

for CLUSTER in sc wc; do
    ck8s_kubespray_config_path="${CK8S_CONFIG_PATH}/${CLUSTER}-config"
    pushd "${ck8s_kubespray_config_path}" || return
    terraform -chdir="${openstack_terraform_dir}" init
    terraform -chdir="${openstack_terraform_dir}" apply -var-file="${ck8s_kubespray_config_path}/cluster.tfvars" -state="${ck8s_kubespray_config_path}/terraform.tfstate"
    popd || return
done
