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
