# Citycloud snippets

To set up a cluster on citycloud these snippets can be used

Start by setting up some environments for this setup

```bash
SERVICE_CLUSTER="my-new-sc-cluster"
WORKLOAD_CLUSTERS=( "my-new-wc-cluster" )
PUB_SSH_KEY_FILE="${HOME}/.ssh/id_rsa.pub"
```

> Tip:
> Save these into a file `my-new-cluster.env`.
> The next time you want to use these snippets you can just run `source my-new-cluster.env`

Then you'll need to set up some openstack specific variables for the infrastructure

```bash
OS_IMAGE_NAME="Ubuntu 20.04 Focal Fossa 20200423" # Image name to base VMs on
OS_NUM_MASTERS=3
OS_MASTERS_FLAVOR="" # UUID of master flavor
OS_NUM_WORKERS=3
OS_WORKER_FLAVOR="" # UUID of worker flavor
OS_EXT_NET_ID="" # UUID of the external network
OS_SUBNET_CIDR="10.10.0.0/24" # (Guessing) CIDR of network
OS_FLOATINGIP_POOL="" # Name of the pool to get floating ips from
```

Set up the clusters into respective folders

```bash
pushd kubespray
for CLUSTER in "${SERVICE_CLUSTER}" "${WORKLOAD_CLUSTERS[@]}"; do
  mkdir -p "inventory/${CLUSTER}/group_vars"
  # shellcheck disable=SC2016
  sed -e "s@^cluster_name = .*@cluster_name = \"${CLUSTER}\"@" \
      -e "s@^public_key_path = .*@public_key_path = \"${PUB_SSH_KEY_FILE}\"@" \
      -e "s@^image = .*@image = \"${OS_IMAGE_NAME}\"@" \
      -e "s@^ssh_user = .*@ssh_user = \"ubuntu\"@" \
      -e "s@^number_of_k8s_masters = .*@number_of_k8s_masters = ${OS_NUM_MASTERS}@" \
      -e "s@^number_of_k8s_nodes = .*@number_of_k8s_nodes = ${OS_NUM_WORKERS}@" \
      -e "s@^number_of_k8s_nodes_no_floating_ip = .*@number_of_k8s_nodes_no_floating_ip = 0@" \
      -e "s@^flavor_k8s_master = .*@flavor_k8s_master = \"${OS_MASTERS_FLAVOR}\"@" \
      -e "s@^#\?flavor_k8s_node = .*@flavor_k8s_node = \"${OS_WORKER_FLAVOR}\"@" \
      -e "s@^network_name = .*@network_name = \"${CLUSTER}-network\"@" \
      -e "s@^external_net = .*@external_net = \"${OS_EXT_NET_ID}\"@" \
      -e "s@^subnet_cidr = .*@subnet_cidr = \"${OS_SUBNET_CIDR}\"@" \
      -e "s@^floatingip_pool = .*@floatingip_pool = \"${OS_FLOATINGIP_POOL}\"@" \
  < "contrib/terraform/openstack/sample-inventory/cluster.tfvars" > "inventory/$CLUSTER/cluster.tfvars"
done
popd
```

Check the `cluster.tfvars` file and make sure your settings are what you want.
If you want to be able to ssh into the machines you need to set the `k8s_allowed_remote_ips` variable to something like:

```tfvars
k8s_allowed_remote_ips = ["1.2.3.4/32"]
```

Now you're ready to deploy the infrastructure

```bash
for CLUSTER in "${SERVICE_CLUSTER}" "${WORKLOAD_CLUSTERS[@]}"; do
  pushd "kubespray/inventory/${CLUSTER}"
  terraform init ../../contrib/terraform/openstack
  terraform apply \
    -var-file cluster.tfvars \
    -auto-approve \
    -state="tfstate-${CLUSTER}.tfstate" \
    ../../contrib/terraform/openstack
  popd
done
```

If all went well the infrastructure should now be up and running

## Compliantkubernetes kubespray

To set up kubernetes with compliantkubernetes-kubespray you can follow these steps.

Export your cluster path and PGP fingerprint

```bash
export CK8S_CONFIG_PATH=~/.ck8s/my-new-cluster
export CK8S_PGP_FP=<Your PGP fingerprint>
```

Initialize the configuration with.

```bash
for CLUSTER in "${SERVICE_CLUSTER}" "${WORKLOAD_CLUSTERS[@]}"; do
  ./bin/ck8s-kubespray init "${CLUSTER}" citycloud ~/.ssh/id_rsa
  ln -s "$(pwd)/kubespray/inventory/${CLUSTER}/tfstate-${CLUSTER}.tfstate" "${CK8S_CONFIG_PATH}/${CLUSTER}-config/" || true
  cp "kubespray/contrib/terraform/openstack/hosts" "${CK8S_CONFIG_PATH}/${CLUSTER}-config/inventory.ini"
  chmod +x "${CK8S_CONFIG_PATH}/${CLUSTER}-config/inventory.ini"
done
```

Check the variables in the `group_vars` folder for each cluster and make sure that it matches what you want.

Apply the configuration and set up kubernetes.

```bash
for CLUSTER in "${SERVICE_CLUSTER}" "${WORKLOAD_CLUSTERS[@]}"; do
  TERRAFORM_STATE_ROOT=${CK8S_CONFIG_PATH}/${CLUSTER}-config/ bin/ck8s-kubespray apply "${CLUSTER}"
done
```

Done!

## Teardown

Later when you want to destroy the infrastructure.

Make sure all cloud resources are destroyed (persistent volumes, load balancers).
Then run the following:

```bash
for CLUSTER in "${SERVICE_CLUSTER}" "${WORKLOAD_CLUSTERS[@]}"; do
  pushd "kubespray/inventory/${CLUSTER}"
  terraform destroy \
    -var-file cluster.tfvars \
    -auto-approve \
    -state="tfstate-${CLUSTER}.tfstate" \
    ../../contrib/terraform/openstack
  popd
done
```
