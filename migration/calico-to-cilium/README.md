# Migrating Kubespray clusters from Calico to Cilium CNI

> [!NOTE]
> Clusters will be migrated one at a time depending on the environment variable `TARGET_CLUSTER`.
>
> It does not matter which cluster is migrated first, but it is recommended to start the migration with the _service_ cluster.
>
> It's also worth mentioning that full network connectivity is maintained between the Calico and Cilium subnets during the migration.
>
> For reference, it takes about 5 minutes to complete the disruptive parts of this guide, on a cluster with 5 nodes.

> [!IMPORTANT]
> This guide assumes all commands are run from the `migration/calico-to-cilium` directory of the `compliantkubernetes-kubespray` repository.

> [!IMPORTANT]
> The Cilium pod subnet is preconfigured to `10.235.64.0/18`, in accordance with the recommended value from the official documentation.
>
> This should prevent any overlaps with the Calico subnet, assumed to have the `10.233.0.0/16` prefix.

## Prerequisites

The migration uses the Cilium CLI for status checks, as well as the `evict` plugin for `kubectl`.

You will need to install the following on your system:

### Golang

On Ubuntu: `sudo apt install golang-go`

### The Cilium CLI

Grab the binary from the [GitHub releases page](https://github.com/cilium/cilium-cli/releases) and put it somewhere in your `PATH`.

To have it installed under `${HOME}/.local/bin`:

```shell
mkdir -p "${HOME}/.local/bin"
curl -fsSL -o- https://github.com/cilium/cilium-cli/releases/download/v0.18.7/cilium-linux-amd64.tar.gz | tar -zxv -C "${HOME}/.local/bin"
mv "${HOME}/.local/bin/cilium" "${HOME}/.local/bin/cilium-cli"
```

> [!NOTE]
> This assumes that the `${HOME}/.local/bin` directory is within your `PATH`. If that's not the case:
> `export PATH="$PATH:$HOME/.local/bin"`

> [!IMPORTANT]
> The migration scripts assume the executable name for the Cilium CLI is `cilium-cli` and _NOT_ `cilium`.

### The `evict` plugin for `kubectl`

```shell
go install github.com/ueokande/kubectl-evict@latest
```

## Prepare

These steps can be performed without any disruption to the target cluster.

- Prepare environment variables:

  ```bash
  export TARGET_CLUSTER="<sc|wc>"
  export CK8S_CONFIG_PATH="/path/to/cluster/config"
  export KUBECONFIG="${CK8S_CONFIG_PATH}/.state/kube_config_${TARGET_CLUSTER}.yaml"
  ```

- This guide includes a complete Kubespray run for the target cluster. For OpenStack _or_ Upcloud clusters, credentials must be sourced:

  ```bash
  test -f ${CK8S_CONFIG_PATH}/openrc.sh && source ${CK8S_CONFIG_PATH}/openrc.sh
  test -f ${CK8S_CONFIG_PATH}/secret/openstack-app-credentials-for-kubespray.sh && source <(sops -d ${CK8S_CONFIG_PATH}/secret/openstack-app-credentials-for-kubespray.sh)
  test -f ${CK8S_CONFIG_PATH}/secret/upcloud-customer-credentials.sh && source <(sops -d ${CK8S_CONFIG_PATH}/secret/upcloud-customer-credentials.sh)
  ```

- Ensure that the checked out tag or commit in your Kubespray repository matches the version in the cluster:

  ```bash
  KUBESPRAY_REF="$(yq '.ck8sKubesprayVersion' ${CK8S_CONFIG_PATH}/${TARGET_CLUSTER}-config/group_vars/all/ck8s-kubespray-general.yaml)"
  git switch --detach "${KUBESPRAY_REF}"

  # update the kubespray submodule if needed
  git submodule sync
  git submodule update --init --recursive
  ```

- Switch `kube_owner` to `root` and apply the changes:

  ```bash
  yq -i '.kube_owner = "root"' "${CK8S_CONFIG_PATH}/${TARGET_CLUSTER}-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml"
  ../../bin/ck8s-kubespray apply $TARGET_CLUSTER -b -e=ignore_assert_errors=true --skip-tags=multus
  ```

- Install Cilium using the values provided in the `cilium-chart-values` directory and wait for the `DaemonSet` rollout:

  ```bash
  cilium-cli install --version 1.17.5 -f cilium-chart-values/cilium-values.yaml -f cilium-chart-values/cilium-extra.yaml
  kubectl -n kube-system rollout status daemonset/cilium --watch
  ```

- Enable the [Per-node configuration](https://docs.cilium.io/en/v1.17/configuration/per-node-config/) feature:

  ```bash
  kubectl apply -f cilium-node-config/during-migration.yaml
  ```

## Execute

These steps will cause disruption in the target cluster.

### 1. Temporarily allow all traffic through Calico

```bash
kubectl apply -f policies/calico-allow-all.yaml
```

### 2. Migrate worker nodes

Get the list of worker nodes and migrate them one by one, passing the node name as argument to the `./20-migrate-node.sh` script.

For example:

```bash
kubectl get nodes --no-headers -o custom-columns=":metadata.name" |
  grep -v 'control-plane' |
  xargs -rt -I{} --interactive ./20-migrate-node.sh {}
```

> [!NOTE]
> If the environment is running a PostgreSQL cluster the migration script might have trouble evicting the postgres pods due to its poddisruptionsbudget.
> This will require manual intervention to fix by manually triggering a leader switchover.
>
> ```sh
> kubectl exec -it <master-pod-name> -n postgres-system -- bash
> $ patronictl switchover
> $ # press enter for the default options and 'y' at the end
> ```

> [!TIP]
> To skip confirmation prompts for each node, remove the `--interactive` flag from `xargs`.

### 3. Migrate control plane nodes

Get the list of control plane nodes and migrate them one by one, passing the node name as argument to the `./20-migrate-node.sh` script.

For example:

```bash
kubectl get nodes --no-headers -o custom-columns=":metadata.name" |
  grep 'control-plane' |
  xargs -rt -I{} --interactive ./20-migrate-node.sh {}
```

### 4. Switch the Kubespray configuration to Cilium

```bash
./80-switch-to-cilium.sh
../../bin/ck8s-kubespray apply $TARGET_CLUSTER -b -e=ignore_assert_errors=true --tags="download,network"
```

Rollout Cilium so it picks up its Kubespray configuration:

```bash
./85-rollout-cilium.sh
```

### 5. Cleanup

- Remove the per-node Cilium configuration:

  ```bash
  kubectl -n kube-system delete ciliumnodeconfigs.cilium.io cilium-default
  ```

- Remove Calico remnants:

  ```bash
  ./90-cleanup-calico.sh
  ```

### 6. Restart Kube Controller Manager

The kube-controller-manager pods might have a stale view of the cluster after the migration. This can cause alerts such as KubeDaemonSetMisScheduled, where the controller managers get confused about how many replicas of a DaemonSet should exist. Restarting the pods fixes this.

```bash
ansible -i "${CK8S_CONFIG_PATH}/${TARGET_CLUSTER}-config/inventory.ini" kube_control_plane --forks 1 -m shell -a 'sudo mv /etc/kubernetes/manifests/kube-controller-manager.yaml . && sleep 5 && sudo mv kube-controller-manager.yaml /etc/kubernetes/manifests/kube-controller-manager.yaml && sleep 10'
```

### 7. (Optional) Reconfigure Apps

> [!NOTE]
> Perform this step after _both_ clusters have been migrated.

If Welkin Apps has been deployed in the environment, it will require a reconfiguration step:

```bash
export CK8S_APPS_REPOSITORY_PATH=/path/to/welkin-apps

yq -i '.networkPlugin.type = "cilium"' "${CK8S_CONFIG_PATH}/common-config.yaml"
yq -i '.networkPlugin.calico.calicoAccountant.enabled = false' "${CK8S_CONFIG_PATH}/common-config.yaml"
yq -i '.networkPlugin.calico.calicoFelixMetrics.enabled = false' "${CK8S_CONFIG_PATH}/common-config.yaml"

${CK8S_APPS_REPOSITORY_PATH}/bin/update-ips.bash both dry-run
${CK8S_APPS_REPOSITORY_PATH}/bin/update-ips.bash both apply

${CK8S_APPS_REPOSITORY_PATH}/bin/ck8s apply sc --concurrency=$(nproc)
${CK8S_APPS_REPOSITORY_PATH}/bin/ck8s apply wc --concurrency=$(nproc)
```

### 8. (Optional) Reconfigure AMS:es

If the environment has any AMS installed, it will be required to update the Network Policies of them, as described the their respective repository.
