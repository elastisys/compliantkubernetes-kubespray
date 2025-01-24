#!/bin/bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

openstack_upcloud_dir="${HERE}/../../../kubespray/contrib/terraform/upcloud"

clusters=()

if [[ "${CK8S_CLUSTER}" == "both" ]]; then
  clusters+=("sc")
  clusters+=("wc")
else
  clusters+=("${CK8S_CLUSTER}")
fi

for cluster in "${clusters[@]}"; do

  export TF_VAR_inventory_file="${CK8S_CONFIG_PATH}/${cluster}-config/inventory.ini"

  log_info "Enter the new name for the loadbalancer:"
  read -r lb_name
  if [[ -z "${lb_name}" ]]; then
    log_fatal "No loadbalancer was given!"
  fi

  if [[ -n $(jq -r '.resources[] | select(.type == "upcloud_loadbalancer") | .instances[] | select(.index_key == 0)' "${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate) ]]; then
      LB_ID=$(jq -r '.resources[] | select(.type == "upcloud_loadbalancer") | .instances[] |  select(.index_key == 0) | .attributes.id' "${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate)
      terraform -chdir="${openstack_upcloud_dir}" import -state="${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate -var-file "${CK8S_CONFIG_PATH}/${cluster}-config"/cluster.tfvars "module.kubernetes.upcloud_loadbalancer.lb[\"${lb_name}\"]" "${LB_ID}"
      terraform -chdir="${openstack_upcloud_dir}" state rm -state="${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate 'module.kubernetes.upcloud_loadbalancer.lb[0]'
  fi

  if [[ -n $(jq -rc '.resources[] | select(.type == "upcloud_loadbalancer_backend") | .instances[].attributes.id' "${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate) ]]; then
      mapfile -t LB_BACKEND_IDS < <(jq -rc '.resources[] | select(.type == "upcloud_loadbalancer_backend") | .instances[].attributes.id' "${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate)
      for lb_backend in "${LB_BACKEND_IDS[@]}"; do
          lb_backend_name=$(jq -r ".resources[] | select(.type == \"upcloud_loadbalancer_backend\") | .instances[] | select(.attributes.id == \"${lb_backend}\") | .index_key" "${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate)
          if [[ "${lb_backend_name}" != "${lb_name}"* ]]; then
              terraform -chdir="${openstack_upcloud_dir}" import -state="${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate -var-file "${CK8S_CONFIG_PATH}/${cluster}-config"/cluster.tfvars "module.kubernetes.upcloud_loadbalancer_backend.lb_backend[\"${lb_name}-${lb_backend_name}\"]" "${lb_backend}"
              terraform -chdir="${openstack_upcloud_dir}" state rm -state="${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate "module.kubernetes.upcloud_loadbalancer_backend.lb_backend[\"${lb_backend_name}\"]"
          fi
      done
  fi

  if [[ -n $(jq -r '.resources[] | select(.type == "upcloud_loadbalancer_frontend") | .instances[].attributes.id' "${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate) ]]; then
      mapfile -t LB_FRONTEND_IDS < <(jq -r '.resources[] | select(.type == "upcloud_loadbalancer_frontend") | .instances[].attributes.id' "${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate)
      for lb_frontend in "${LB_FRONTEND_IDS[@]}"; do
          lb_frontend_name=$(jq -r ".resources[] | select(.type == \"upcloud_loadbalancer_frontend\") | .instances[] |  select(.attributes.id == \"${lb_frontend}\") | .index_key" "${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate)
          if [[ "${lb_frontend_name}" != "${lb_name}"* ]]; then
              terraform -chdir="${openstack_upcloud_dir}" import -state="${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate -var-file "${CK8S_CONFIG_PATH}/${cluster}-config"/cluster.tfvars "module.kubernetes.upcloud_loadbalancer_frontend.lb_frontend[\"${lb_name}-${lb_frontend_name}\"]" "${lb_frontend}"
              terraform -chdir="${openstack_upcloud_dir}" state rm -state="${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate "module.kubernetes.upcloud_loadbalancer_frontend.lb_frontend[\"${lb_frontend_name}\"]"
          fi
      done
  fi

  if [[ -n $(jq -r '.resources[] | select(.type == "upcloud_loadbalancer_static_backend_member") | .instances[].attributes.id' "${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate) ]]; then
      mapfile -t LB_STATIC_BACKEND_IDS < <(jq -r '.resources[] | select(.type == "upcloud_loadbalancer_static_backend_member") | .instances[].attributes.id' "${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate)
      for lb_static_backend in "${LB_STATIC_BACKEND_IDS[@]}"; do
          lb_static_backend_name=$(jq -r ".resources[] | select(.type == \"upcloud_loadbalancer_static_backend_member\") | .instances[] |  select(.attributes.id == \"${lb_static_backend}\") | .index_key" "${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate)
          if [[ "${lb_static_backend_name}" != "${lb_name}"* ]]; then
              terraform -chdir="${openstack_upcloud_dir}" import -state="${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate -var-file "${CK8S_CONFIG_PATH}/${cluster}-config"/cluster.tfvars "module.kubernetes.upcloud_loadbalancer_static_backend_member.lb_backend_member[\"${lb_name}-${lb_static_backend_name}\"]" "${lb_static_backend}"
              terraform -chdir="${openstack_upcloud_dir}" state rm -state="${CK8S_CONFIG_PATH}/${cluster}-config"/terraform.tfstate "module.kubernetes.upcloud_loadbalancer_static_backend_member.lb_backend_member[\"${lb_static_backend_name}\"]"
          fi
      done
  fi

done
