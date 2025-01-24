#!/bin/bash

# This migration removes the old loadbalancer from the Terraform state and imports the new loadbalancers into state.

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"
: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <name of lb to migrate>" >&2
  exit 1
fi

lb_name="${1}"

openstack_upcloud_dir="${ROOT}/kubespray/contrib/terraform/upcloud"

clusters=()

if [[ "${CK8S_CLUSTER}" == "both" ]]; then
  clusters+=("sc")
  clusters+=("wc")
else
  clusters+=("${CK8S_CLUSTER}")
fi

for cluster in "${clusters[@]}"; do

  export TF_VAR_inventory_file="${CK8S_CONFIG_PATH}/${cluster}-config/inventory.ini"

  terraform_state_file="${CK8S_CONFIG_PATH}/${cluster}-config/terraform.tfstate"
  terraform_var_file="${CK8S_CONFIG_PATH}/${cluster}-config/cluster.tfvars"

  lb_state="$(jq -r '.resources[] | select(.type == "upcloud_loadbalancer") | .instances[] | select(.index_key == 0)' "${terraform_state_file}")"

  if [[ -n "${lb_state}" ]]; then
    lb_id="$(jq -r '.attributes.id' <<<"${lb_state}")"
    terraform -chdir="${openstack_upcloud_dir}" import -state="${terraform_state_file}" -var-file "${terraform_var_file}" "module.kubernetes.upcloud_loadbalancer.lb[\"${lb_name}\"]" "${lb_id}"
    terraform -chdir="${openstack_upcloud_dir}" state rm -state="${terraform_state_file}" 'module.kubernetes.upcloud_loadbalancer.lb[0]'
  fi

  mapfile -t lb_backend_ids < <(jq -rc '.resources[] | select(.type == "upcloud_loadbalancer_backend") | .instances[].attributes.id' "${terraform_state_file}")

  if [[ "${#lb_backend_ids[@]}" -gt 0 ]]; then
    for lb_backend_id in "${lb_backend_ids[@]}"; do
      lb_backend_name="$(jq -rc '.resources[] | select(.type == "upcloud_loadbalancer_backend") | .instances[] | select(.attributes.id == "'"${lb_backend_id}"'") | .index_key' "${terraform_state_file}")"
      if [[ "${lb_backend_name}" != "${lb_name}"* ]]; then
        terraform -chdir="${openstack_upcloud_dir}" import -state="${terraform_state_file}" -var-file "${terraform_var_file}" 'module.kubernetes.upcloud_loadbalancer_backend.lb_backend["'"${lb_name}-${lb_backend_name}"'"]' "${lb_backend_id}"
        terraform -chdir="${openstack_upcloud_dir}" state rm -state="${terraform_state_file}" 'module.kubernetes.upcloud_loadbalancer_backend.lb_backend["'"${lb_backend_name}"'"]'
      fi
    done
  fi

  mapfile -t lb_frontend_ids < <(jq -rc '.resources[] | select(.type == "upcloud_loadbalancer_frontend") | .instances[].attributes.id' "${terraform_state_file}")

  if [[ "${#lb_frontend_ids[@]}" -gt 0 ]]; then
    for lb_frontend_id in "${lb_frontend_ids[@]}"; do
      lb_frontend_name=$(jq -r '.resources[] | select(.type == "upcloud_loadbalancer_frontend") | .instances[] |  select(.attributes.id == "'"${lb_frontend_id}"'") | .index_key' "${terraform_state_file}")
      if [[ "${lb_frontend_name}" != "${lb_name}"* ]]; then
        terraform -chdir="${openstack_upcloud_dir}" import -state="${terraform_state_file}" -var-file "${terraform_var_file}" 'module.kubernetes.upcloud_loadbalancer_frontend.lb_frontend["'"${lb_name}-${lb_frontend_name}"'"]' "${lb_frontend_id}"
        terraform -chdir="${openstack_upcloud_dir}" state rm -state="${terraform_state_file}" 'module.kubernetes.upcloud_loadbalancer_frontend.lb_frontend["'"${lb_frontend_name}"'"]'
      fi
    done
  fi

  mapfile -t lb_static_backend_ids < <(jq -rc '.resources[] | select(.type == "upcloud_loadbalancer_static_backend_member") | .instances[].attributes.id' "${terraform_state_file}")

  if [[ "${#lb_static_backend_ids[@]}" -gt 0 ]]; then
    for lb_static_backend_id in "${lb_static_backend_ids[@]}"; do
      lb_static_backend_name=$(jq -r '.resources[] | select(.type == "upcloud_loadbalancer_static_backend_member") | .instances[] |  select(.attributes.id == "'"${lb_static_backend_id}"'") | .index_key' "${terraform_state_file}")
      if [[ "${lb_static_backend_name}" != "${lb_name}"* ]]; then
        terraform -chdir="${openstack_upcloud_dir}" import -state="${terraform_state_file}" -var-file "${terraform_var_file}" 'module.kubernetes.upcloud_loadbalancer_static_backend_member.lb_backend_member["'"${lb_name}-${lb_static_backend_name}"'"]' "${lb_static_backend_id}"
        terraform -chdir="${openstack_upcloud_dir}" state rm -state="${terraform_state_file}" 'module.kubernetes.upcloud_loadbalancer_static_backend_member.lb_backend_member["'"${lb_static_backend_name}"'"]'
      fi
    done
  fi
done
