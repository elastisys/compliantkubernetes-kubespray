# Upgrade Rook-Ceph operator and Ceph

This doc will guide you through upgrading the Rook-Ceph operator from version `v1.5` to `v1.10`, and Ceph from `v15` to `v17`.

## Steps

### Prerequisites

```bash
# Go to rook directory in compliantkubernetes-kubespray
cd /path/to/compliantkubernetes-kubespray/rook

# Add and update rook helm repo
helm repo add rook-release https://charts.rook.io/release && helm repo update

# Set variables
namespace="rook-ceph"
release_name="rook-ceph"
chart="rook-release/rook-ceph"

# Set kubeconfig
export KUBECONFIG=/path/to/kubeconfig
```

Before all upgrades make sure that the Ceph cluster is in a healthy state.
You can find some details on how to verify the health [here](https://rook.io/docs/rook/v1.10/Upgrade/health-verification/#pods-all-running).

After an upgrade you should also verify the status of the components before proceeding.

Here are some useful commands that can be used to check the version of the components

```bash
kubectl -n ${namespace} exec -it deployments/rook-ceph-tools -- ceph -s

kubectl -n ${namespace} get deployments -o jsonpath='{range .items[*]}{.metadata.name}{"  \treq/upd/avl: "}{.spec.replicas}{"/"}{.status.updatedReplicas}{"/"}{.status.readyReplicas}{"  \trook-version="}{.metadata.labels.rook-version}{"\n"}{end}'

kubectl -n ${namespace} get jobs -o jsonpath='{range .items[*]}{.metadata.name}{"  \tsucceeded: "}{.status.succeeded}{"      \trook-version="}{.metadata.labels.rook-version}{"\n"}{end}'

watch --exec kubectl -n ${namespace} get deployments -l rook_cluster=${namespace} -o jsonpath='{range .items[*]}{.metadata.name}{"  \treq/upd/avl: "}{.spec.replicas}{"/"}{.status.updatedReplicas}{"/"}{.status.readyReplicas}{"  \trook-version="}{.metadata.labels.rook-version}{"\n"}{end}'
```

### Operator to v1.6

Go [here](https://rook.io/docs/rook/v1.6/ceph-upgrade.html) for the official upgrade docs.

```bash
chart_version="v1.6.11"

# Check diff
helm diff upgrade --install --namespace "${namespace}" "${release_name}" "${chart}" \
  --version "${chart_version}" --values operator-values.yaml

# Upgrade
helm upgrade --install --namespace "${namespace}" "${release_name}" "${chart}" \
  --version "${chart_version}" --values operator-values.yaml --wait
```

### Operator to v1.7

```bash
chart_version="v1.7.11"

# Check diff
helm diff upgrade --install --namespace "${namespace}" "${release_name}" "${chart}" \
  --version "${chart_version}" --values operator-values.yaml

# Upgrade
helm upgrade --install --namespace "${namespace}" "${release_name}" "${chart}" \
  --version "${chart_version}" --values operator-values.yaml --wait
```

### Ceph to v16

Skip this step if you are already running Ceph `v16`.

If you are using a custom manifest for your CephCluster deployment you need to update `spec.cephVersion.image` to `quay.io/ceph/ceph:v16.2.10`, and apply the changes.

If you have deployed ceph using the provided `cluster.yaml` from a previous version of this repo, you can simply deploy the manifest `migration/rook-1.5.x-rook-1.10.5/cluster-16.2.10.yaml`

```bash
kubectl apply -f migration/rook-1.5.x-rook-1.10.5/cluster-16.2.10.yaml
```

If you see this or a similar message

> HEALTH_WARN all OSDs are running pacific or later but require_osd_release < pacific

you need to execute the following command

```bash
kubectl -n ${namespace} exec -it deployments/rook-ceph-tools -- ceph osd require-osd-release pacific
```

### Operator to v1.8

```bash
chart_version="1.8.10"

# Check diff
helm diff upgrade --install --namespace "${namespace}" "${release_name}" "${chart}" \
  --version "${chart_version}" --values operator-values.yaml

# Upgrade
helm upgrade --install --namespace "${namespace}" "${release_name}" "${chart}" \
  --version "${chart_version}" --values operator-values.yaml --wait
```

### Operator to v1.9

```bash
chart_version="1.9.12"

# Check diff
helm diff upgrade --install --namespace "${namespace}" "${release_name}" "${chart}" \
  --version "${chart_version}" --values operator-values.yaml

# Upgrade
helm upgrade --install --namespace "${namespace}" "${release_name}" "${chart}" \
  --version "${chart_version}" --values operator-values.yaml --wait
```

### Operator to 1.10

```bash
chart_version="1.10.5"

# Check diff
helm diff upgrade --install --namespace "${namespace}" "${release_name}" "${chart}" \
  --version "${chart_version}" --values operator-values.yaml

# Upgrade
helm upgrade --install --namespace "${namespace}" "${release_name}" "${chart}" \
  --version "${chart_version}" --values operator-values.yaml --wait
```

### Ceph to v17

Skip this step if you are already running Ceph `v17`.

If you are using a custom manifest for your CephCluster deployment you need to update `spec.cephVersion.image` to `quay.io/ceph/ceph:v17.2.5`, and apply the changes.

If you have deployed ceph using the provided `cluster.yaml` from a previous version of this repo, you can simply deploy the manifest `migration/rook-1.5.x-rook-1.10.5/cluster-17.2.5.yaml`

```bash
kubectl apply -f migration/rook-1.5.x-rook-1.10.5/cluster-17.2.5.yaml
```

### Update rook-ceph-tools

```bash
kubectl apply -f toolbox-deploy.yaml
```
