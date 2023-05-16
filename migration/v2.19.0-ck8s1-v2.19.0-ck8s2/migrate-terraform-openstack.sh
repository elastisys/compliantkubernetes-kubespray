#!/bin/bash
# shellcheck disable=SC2002

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
: "${OS_USERNAME:?Missing OS_USERNAME}"
: "${OS_PASSWORD:?Missing OS_PASSWORD}"

here="$(dirname "$(readlink -f "$0")")"
openstack_terraform_dir="${here}/../../kubespray/contrib/terraform/openstack"

# shellcheck disable=SC1090
# shellcheck disable=SC1091
source "${CK8S_CONFIG_PATH}/openrc.sh"

# Rendered cloudinit template file with nothing in it, will always be the same for already set up clusters
USER_DATA=a59f82a5a0ceedbc94016fb22248ba033dfcb315

for CLUSTER in sc wc; do
  pushd "${CK8S_CONFIG_PATH}/${CLUSTER}-config" || return
  terraform init "${openstack_terraform_dir}"
  node_ids=( "$(cat terraform.tfstate | jq -r '.resources[] | select(.type == "openstack_compute_instance_v2").instances[].attributes.id')" )
  cp terraform.tfstate terraform-temp.tfstate
  echo "Getting openstack ports"
  openstack port list -f json > ports.json

  # shellcheck disable=SC2068
  for node in ${node_ids[@]}; do
      mac_address=$(cat terraform.tfstate | jq -r '.resources[] | select(.type == "openstack_compute_instance_v2").instances[] | select(.attributes.id == "'"${node}"'").attributes.network[].mac')
      port_id=$(cat ports.json | jq -r '.[] | select(."MAC Address" == "'"${mac_address}"'").ID')
      node_type_name=$(cat terraform.tfstate | jq -r '.resources[] | select(.type == "openstack_compute_instance_v2" and .instances[].attributes.id == "'"${node}"'").name')
      index_key=$(cat terraform.tfstate | jq -r '.resources[] | select(.type == "openstack_compute_instance_v2").instances[] | select(.attributes.id == "'"${node}"'").index_key')
      # Check if index key is a number or not, to determine how the imported ports should be indexed
      # Then, terraform import the openstack ports
      re='^[0-9]+$'
      if [[ "${index_key}" =~ $re ]]; then
        terraform import -state=terraform-temp.tfstate -config="${openstack_terraform_dir}" -var-file=cluster.tfvars module.compute.openstack_networking_port_v2."${node_type_name}"_port["${index_key}"] "${port_id}"
      else
        terraform import -state=terraform-temp.tfstate -config="${openstack_terraform_dir}" -var-file=cluster.tfvars module.compute.openstack_networking_port_v2."${node_type_name}"_port[\""${index_key}"\"] "${port_id}"
      fi
      # Add port ID to node resource
      cat terraform-temp.tfstate | jq -r '(.resources[] | select(.type == "openstack_compute_instance_v2").instances[] | select(.attributes.id == "'"${node}"'").attributes.network[].port) = "'"${port_id}"'"' > terraform-temp2.tfstate
      mv terraform-temp2.tfstate terraform-temp.tfstate
  done

  # Add user_data field to nodes
  cat terraform-temp.tfstate | jq -r '(.resources[] | select(.type == "openstack_compute_instance_v2" and .name != "k8s_master_no_floating_ip").instances[].attributes.user_data) = "'"${USER_DATA}"'"' > terraform-temp2.tfstate
  mv terraform-temp2.tfstate terraform-temp.tfstate
  rm ports.json
  popd || return
done

echo "New terraform state can be found in ${CK8S_CONFIG_PATH}/<sc|wc>-config/terraform-temp.tfstate"
echo "Try running terraform plan with this state to see that no nodes get destroyed, then mv terraform-temp.tfstate terraform.tfstate"
echo "Then, run terraform apply to finish making the changes"
