#!/bin/bash
# shellcheck disable=SC2002

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
: "${OS_USERNAME:?Missing OS_USERNAME}"
: "${OS_PASSWORD:?Missing OS_PASSWORD}"

here="$(dirname "$(readlink -f "$0")")"
openstack_terraform_dir="${here}/../../kubespray/contrib/terraform/openstack"

# shellcheck disable=SC1090,SC2181
source "${CK8S_CONFIG_PATH}/openrc.sh"

OLD_USER_DATA=a59f82a5a0ceedbc94016fb22248ba033dfcb315
NEW_USER_DATA=63693c2eae01dc6dd77bbee68991ba6090a19a2b

for CLUSTER in sc wc; do
    ck8s_kubespray_config_path="${CK8S_CONFIG_PATH}/${CLUSTER}-config"
    pushd "${ck8s_kubespray_config_path}" || return
    cat terraform.tfstate | jq -r '(.resources[].instances[].attributes | select(.user_data == "'"${OLD_USER_DATA}"'").user_data) = "'"${NEW_USER_DATA}"'"' > terraform-temp.tfstate
    terraform -chdir="${openstack_terraform_dir}" init
    export TF_VAR_group_vars_path="${CK8S_CONFIG_PATH}/${CLUSTER}-config"
    if ! terraform -chdir="${openstack_terraform_dir}" plan -var-file="${ck8s_kubespray_config_path}/cluster.tfvars" -state="${ck8s_kubespray_config_path}/terraform-temp.tfstate" -detailed-exitcode; then
        echo "Terraform found changes for $CLUSTER-cluster, review the changes."
        echo "Continuing here will not apply anything, it will just create a temporary state file."
        read -rp "Continue? [y/N] " val
        case "${val}" in
            [Yy]) ;;
            *) exit ;;
        esac
    fi
    popd || return
done
