# Migrating Kubespray cluster from Calico to Cilium CNI

> [!NOTE]
> Clusters will be migrated one at a time depending on the environment variable `TARGET_CLUSTER`.
>
> It does not matter which cluster is migrated first, but it is recommended to start the migration with the _service_ cluster.
>
> For reference, it takes about 5 minutes to complete the disruptive parts of this guide, on a cluster with 5 nodes.

## Prerequisites

The migration uses the Cilium CLI for status checks, as well as the `evict` plugin for `kubectl`.

You will need to install the following on your system:

### Golang

On Ubuntu: `sudo apt install golang-go`

### The Cilium CLI

Grab the binary from the [GitHub releases page](https://github.com/cilium/cilium-cli/releases) and put it somewhere in your `PATH`.

To have it installed under `${HOME}/bin`:

```shell
mkdir -p "${HOME}/bin"
curl -fsSL -o- https://github.com/cilium/cilium-cli/releases/download/v0.18.7/cilium-linux-amd64.tar.gz | tar -zxv -C "${HOME}/.local/bin"
mv "${HOME}/.local/bin/cilium" "${HOME}/.local/bin/cilium-cli"
```

> [!NOTE]
> This assumes that the `${HOME}/.local/bin` directory is within your `PATH`. If that's not the case:
> `export PATH="$PATH:$HOME/.local/bin"`

> [!IMPORTANT]
> The migration scripts assume the executable name for the Cilium CLI is `cilium-cli` and not `cilium`.

### The `evict` plugin for `kubectl`

```shell
go install github.com/ueokande/kubectl-evict@latest
```

## Prepare

These steps can be performed without any disruption to the target cluster.

- Prepare environment variables

  ```bash
  export TARGET_CLUSTER="<sc|wc>"
  export CK8S_CONFIG_PATH="/path/to/cluster/config"
  export CK8S_KUBESPRAY_REPOSITORY_PATH="/path/to/compliantkubernetes-kubespray"
  export KUBECONFIG="${CK8S_CONFIG_PATH}/.state/kube_config_${TARGET_CLUSTER}.yaml"
  ```

- Ensure that the checked out tag in your Kubespray repository matches the version in the cluster.

- Switch `kube_owner` to `root` in the `${CK8S_CONFIG_PATH}/${TARGET_CLUSTER}_config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` file
  and apply the changes:

  ```bash
  yq -i '.kube_owner = "root"' "${CK8S_CONFIG_PATH}/${TARGET_CLUSTER}-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml"
  pushd "${CK8S_KUBESPRAY_REPOSITORY_PATH}"
  ./bin/ck8s-kubespray apply $TARGET_CLUSTER -b -e=ignore_assert_errors=true --skip-tags=multus
  popd
  ```

- Install Cilium using the values provided in the `cilium-chart-values` directory

  ```bash
  cilium-cli install --version 1.17.5 -f cilium-chart-values/cilium-values.yaml -f cilium-chart-values/cilium-extra.yaml
  ```

- Wait for Cilium DaemonSet to successfully roll out

  ```bash
  kubectl -n kube-system rollout status daemonset/cilium --watch
  ```

> [!NOTE]
> The pod CIDR used by the Cilium installation is `10.235.64.0/18`

- Enable the [Per-node configuration](https://docs.cilium.io/en/v1.17/configuration/per-node-config/) feature

  ```bash
  kubectl apply -f cilium-node-config/during-migration.yaml
  ```

## Execute

These steps will cause disruption in the target cluster.

### Temporarily allow all traffic through Calico

```bash
kubectl apply -f policies/calico-allow-all.yaml
```

### Migrate worker nodes

Get the list of worker nodes and migrate them one by one, passing the node name as argument to the `./20-migrate-node.sh` script.

For example:

```bash
kubectl get nodes --no-headers -o custom-columns=":metadata.name" |
  grep -v 'control-plane' |
  xargs -rt -I{} --interactive ./20-migrate-node.sh {}
```

### Migrate control plane nodes

Get the list of control plane nodes and migrate them one by one, passing the node name as argument to the `./20-migrate-node.sh` script.

For example:

```bash
kubectl get nodes --no-headers -o custom-columns=":metadata.name" |
  grep 'control-plane' |
  xargs -rt -I{} --interactive ./20-migrate-node.sh {}
```

### Switch the Kubespray configuration to Cilium

```bash
./80-switch-to-cilium.sh
```

...and do a Kubespray apply step:

```bash
pushd "${CK8S_KUBESPRAY_REPOSITORY_PATH}"
./bin/ck8s-kubespray apply $TARGET_CLUSTER -b -e=ignore_assert_errors=true --skip-tags="bootstrap-os,preinstall,container-engine,multus"
popd
```

## Cleanup

- Remove the per-node Cilium configuration

  ```bash
  kubectl -n kube-system delete ciliumnodeconfigs.cilium.io cilium-default
  ```

- Remove Calico remnants

  ```bash
  ./90-cleanup-calico.sh
  ```
