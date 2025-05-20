# Labeling and tainting nodes

To add labels and taints to nodes modify the configuration file `node-labels-and-taints.yaml`.

## Syntax

This is the syntax of the configuration file.

```yaml
host_identifier:
  node_labels:
    key: value
  node_taints:
    - key=value:effect
```

The `host_identifier` will substring-match against hosts in the group `k8s_cluster` in the inventory.

## Applying

When running `ck8s-kubespray apply` the node labels and taints will be applied as part of the regular cluster deployment.

To only apply node labels and taints you can run:

```sh
ck8s-kubespray apply <sc|wc> --tags node-label,node-taint
```

## Example

This example shows how the node labels and taints configuration applies.

inventory.ini:

```ini
[all]
foo-sc-control-plane-1
foo-sc-control-plane-2
foo-sc-control-plane-3
foo-sc-worker-1
foo-sc-worker-2
foo-sc-worker-3
foo-sc-worker-4

[kube_control_plane]
foo-sc-control-plane-1
foo-sc-control-plane-2
foo-sc-control-plane-3

[etcd]
foo-sc-control-plane-1
foo-sc-control-plane-2
foo-sc-control-plane-3

[kube_node]
foo-sc-worker-1
foo-sc-worker-2
foo-sc-worker-3
foo-sc-worker-4

[k8s_cluster:children]
kube_control_plane
kube_node
```

node-labels-and-taints.yaml:

```yaml
control-plane:
  node_labels:
    role: control-plane
  node_taints:
    - control-plane:NoSchedule
worker:
  node_labels:
    role: worker
worker-4:
  node_labels:
    special: cargo
  node_taints:
    - special-cargo=true:NoSchedule
```

Result:

```text
foo-sc-control-plane-1 labels(role=control-plane) taints(control-plane:NoSchedule)
foo-sc-control-plane-2 labels(role=control-plane) taints(control-plane:NoSchedule)
foo-sc-control-plane-3 labels(role=control-plane) taints(control-plane:NoSchedule)
foo-sc-worker-1 labels(role=worker) taints()
foo-sc-worker-2 labels(role=worker) taints()
foo-sc-worker-3 labels(role=worker) taints()
foo-sc-worker-4 labels(role=worker, special=cargo) taints(special-cargo=true:NoSchedule)
```
