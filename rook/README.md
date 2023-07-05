# rook-ceph

> **Note**: These instructions assumes that you are standing in this directory and have set `$CK8S_CONFIG_PATH` pointing to your environment.

## Install

### Configure

The configuration is divided into an all cluster `commons` section and per cluster `clusters.<cluster>` section.
Any configuration defined within the per cluster section will override anything set in the all cluster section.
The name of the cluster will become the helmfile environment name.

Many options use default within the helmfile state values.

- Copy template

  ```bash
  mkdir -p "${CK8S_CONFIG_PATH}/rook"
  cp template/values.yaml "${CK8S_CONFIG_PATH}/rook"
  ```

- Set [preset](values/cluster-presets)

  ```diff
    cluster:
      # see rook/helmfile.d/values/cluster-presets
  -   preset: ""
  +   preset: ceph-750
  ```

- Customising

  Placement rules can be defined for all or per component, and resources can be overridden per component.

  Storage rules can be defined, the default is to use all devices on all nodes, and optionally it is possible to create a Block PVC based cluster for development.
  (This requires special config for storage and mon.)

### Deploy

The deployment is divided into two steps the bootstrap and the finalising.
Since parts of the deployment relies on services in apps, such as Gatekeeper constraints and Prometheus operator, and apps relies on rook-ceph for block storage.

- Bootstrap

  > *Before Apps install*

  For both service and workload clusters:

  ```bash
  # with kubeconfig pointing to the correct cluster
  helmfile -e <cluster> -l stage=bootstrap diff
  helmfile -e <cluster> -l stage=bootstrap apply

  # check that the pods starts
  kubectl -n rook-ceph get pods
  # check that the cluster is healthy
  kubectl -n rook-ceph get cephclusters
  ```

  > **Note**: If rook cannot automatically find your disks and create osds for them then [zap the disks](#zap-ceph-disks) and restart the operator for it to rescan.

- Finalise

  > *After Apps install*

  For both service and workload clusters:

  ```bash
  # with kubeconfig pointing to the correct cluster

  ./scripts/autoconfig.sh <cluster>

  helmfile -e <cluster> diff
  helmfile -e <cluster> apply
  ```

  This autoconfig script can be later used to keep networkpolicies up to date.

## Upgrade

Check the [migration guides](migration) between each version.

## Uninstall

- Terminate

  Terminate all Pods using PVCs backed by rook-ceph.

  Terminate all PVCs backed by rook-ceph.

- Destroy

  Destroy the Ceph cluster:

  ```bash
  # with kubeconfig pointing to the correct cluster

  helmfile -e <cluster> -l app=cluster destroy
  ```

  Wait until all resources have been deleted and check that the logs of the operator in case something cannot be deleted.

  Destroy the rest:

  ```bash
  # with kubeconfig pointing to the correct cluster

  helmfile -e <cluster> destroy
  ```

- Finalise

  Delete CRDs:

  ```bash
  # with kubeconfig pointing to the correct cluster

  kubectl delete crds \
    cephblockpoolradosnamespaces.ceph.rook.io \
    cephblockpools.ceph.rook.io \
    cephbucketnotifications.ceph.rook.io \
    cephbuckettopics.ceph.rook.io \
    cephclients.ceph.rook.io \
    cephclusters.ceph.rook.io \
    cephfilesystemmirrors.ceph.rook.io \
    cephfilesystems.ceph.rook.io \
    cephfilesystemsubvolumegroups.ceph.rook.io \
    cephnfses.ceph.rook.io \
    cephobjectrealms.ceph.rook.io \
    cephobjectstores.ceph.rook.io \
    cephobjectstoreusers.ceph.rook.io \
    cephobjectzonegroups.ceph.rook.io \
    cephobjectzones.ceph.rook.io \
    cephrbdmirrors.ceph.rook.io \
    objectbucketclaims.objectbucket.io \
    objectbuckets.objectbucket.io
  ```

### Zap ceph disks

It is good practice to zap all disks used as storage for rook-ceph.
This is required if rook-ceph will be reinstalled on the same cluster to allow it to auto detect disks.

```bash
export IPADDRESSES=( "ip-node-1" "ip-node-2" "..." )

for IP in "${IPADDRESSES[@]}"; do
  ./scripts/zap-disk.sh "${IP}" "<disk parameter if all the nodes use the same: eg. sdX(x) or vdX(x)>"
done
```

### Purge rook data

It is good practice to purge all data stored by rook-ceph.
This is required if rook-ceph will be reinstalled on the same cluster.

```console
ansible all -i "${CK8S_CONFIG_PATH}/sc-config/inventory.ini" --become -m shell -a 'rm -rf /var/lib/rook'
ansible all -i "${CK8S_CONFIG_PATH}/wc-config/inventory.ini" --become -m shell -a 'rm -rf /var/lib/rook'
```
