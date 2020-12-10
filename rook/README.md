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
