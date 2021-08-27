# Rook installation

Also see the official documentation at <https://rook.io/docs/rook/v1.5/> and the repository at <https://github.com/rook/rook>.

## Quickstart

```bash
# Make sure your KUBECONFIG and Kubernetes context are set correctly
./deploy-rook.sh
```

## Requirements

### Ceph partition or disk

An empty disk or partition needs to be available.
Ceph will create an [OSD](https://docs.ceph.com/en/latest/man/8/ceph-osd/) for each partition or disk to provide access to it.

To create an empty partition `/dev/vda2` on the `/dev/vda` disk, leaving 50 GB to other partitions, use the following cloud-init config:

```yaml
#cloud-config
bootcmd:
- [ cloud-init-per, once, move-second-header, sgdisk, --move-second-header, /dev/vda ]
- [ cloud-init-per, once, create-ceph-part, parted, --script, /dev/vda, 'mkpart 2 50GB -1' ]
```

### Nodes for Ceph mons

The Ceph [`mon`s](https://docs.ceph.com/en/latest/man/8/ceph-mon/) should not run on the same node.
Make sure that there are at least as many worker nodes as there are replicas of `mon`s.
See `spec.mon.count` in [cluster.yaml](./cluster.yaml).

### Monitoring with Prometheus

Prometheus Operator CRDs should be installed before applying the Ceph cluster manifest if `spec.monitoring.enabled=true`.

## Installation

See [deploy-rook.sh](./deploy-rook.sh) for an example.

## Issues

If the operator seems to be unable to remove configmaps or deployments, make sure that the Kubernetes API server is able to process requests.
For example, if cert-manager custom resources are created before cert-manager is installed, we experienced cases where the Kubernetes API server did not process requests from the Rook operator.
This was resolved once cert-manager was installed.

## Troubleshoot

Deploying with the script includes a toolbox container that can be used for troubleshooting, see [this](https://www.rook.io/docs/rook/v1.6/ceph-toolbox.html) for more info.
This site includes a lot more info on how to manage a ceph cluster and includes useful snippets.

But to get started with the troubleshooting you can start by running:

```console
$ kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- bash
[root@rook-ceph-tools /]# ceph status
  cluster:
    id:     ab2a424f-b246-4c52-c0a5-d285f6502ca0
    health: HEALTH_WARN
            2 backfillfull osd(s)
            1 nearfull osd(s)
            2 pool(s) backfillfull

  services:
    mon: 3 daemons, quorum a,b,c (age 4d)
    mgr: a(active, since 4d)
    osd: 4 osds: 4 up (since 4d), 4 in (since 3M)

  data:
    pools:   2 pools, 129 pgs
    objects: 77.58k objects, 299 GiB
    usage:   601 GiB used, 79 GiB / 680 GiB avail
    pgs:     129 active+clean

  io:
    client:   23 KiB/s rd, 6.5 MiB/s wr, 3 op/s rd, 111 op/s wr
```

## Uninstall Rook and Zap of disks

First check which disks Rook is using on the nodes and note them down. As they will be used later to zap the disks after rook is removed. If the cloud-init is used to allocate a disks you can skip this part and use them later on.

This is done by for each node with the following command:

```console
./bin/ck8s ops kubectl sc logs -n rook-ceph rook-ceph-osd-prepare-<cluster name>-k8s-node-nf-<node number>
./bin/ck8s ops kubectl wc logs -n rook-ceph rook-ceph-osd-prepare-<cluster name>-k8s-node-nf-<node number>
```

Note down `/dev/sdb`

```console
"devices": [
                "/dev/sdb1"
            ],
```

from

```console
cephosd: {
    "1": [
        {
            "devices": [
                "/dev/sdb1"
            ],
            "lv_name": "osd-data-fd645a6e-ba55-4579-829b-2dfb5229691f",
            "lv_path": "/dev/ceph-15b06b88-5027-419c-a04e-e6e4c616b109/osd-data-fd645a6e-ba55-4579-829b-2dfb5229691f",
            "lv_size": "<170.00g",
            "lv_tags": "ceph.block_device=/dev/ceph-15b06b88-5027-419c-a04e-e6e4c616b109/osd-data-fd645a6e-ba55-4579-829b-2dfb5229691f,ceph.block_uuid=i4StEb-p3KV-jbYK-ng22-0c97-JkBt-20wJ4l,ceph.cephx_lockbox_secret=,ceph.cluster_fsid=3a9596ad-a597-4d00-9bdf-92a26421a092,ceph.cluster_name=ceph,ceph.crush_device_class=None,ceph.encrypted=0,ceph.osd_fsid=ba2b18fd-e129-42b1-9f50-2eb90bf4034b,ceph.osd_id=1,ceph.osdspec_affinity=,ceph.type=block,ceph.
            ...
        }
}
```

### Remove Rook

Then to remove Rook use the following snippet:

```console
./remove-rook.sh
```

### Ensure that Rook is removed

Ensure that Rook is fully removed by looking at resources, some examples are the following:

```console
./bin/ck8s ops kubectl sc get pods -n rook-ceph
./bin/ck8s ops kubectl wc get pods -n rook-ceph
```

```console
./bin/ck8s ops kubectl sc get storageclass
./bin/ck8s ops kubectl wc get storageclass
```

### Zap Rook disks

For each node it is a good idea to zap the disks used by Rook. This needs to be done for each node used as storage in the cluster.

Zap the disks using:

```bash
export IPADDRESSES=( "IP-node-1" "IP-node-2" "..." )
```

```bash
for IP in "${IPADDRESSES[@]}"; do
  ./zap-disk.sh ${IP} "<disk parameter if all the nodes use the same: sXX>"
done
```

### Clean up rook folder

Finally on all the nodes the `/var/lib/rook` needs to be cleaned up.

```console
ansible all -i ${CK8S_CONFIG_PATH}/sc-config/inventory.ini --become -m shell -a 'rm -rf /var/lib/rook'
ansible all -i ${CK8S_CONFIG_PATH}/wc-config/inventory.ini --become -m shell -a 'rm -rf /var/lib/rook'
```
