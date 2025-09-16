# Nuclear option: evict all pods in the cluster

## 🐉 Dragons be here

This is the most disruptive, but also the _quickest_ way to migrate a cluster from Calico to Cilium.

## Prepare

Follow the prepare steps from the [main migration guide](./README.md).

## Execute

These steps will cause disruption in the target cluster.

### Temporarily allow all traffic through Calico

```bash
kubectl apply -f policies/calico-allow-all.yaml
```

### Enable Cilium on all nodes in the cluster

Start by adding the correct label to all nodes:

```bash
kubectl label nodes $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}') --overwrite "io.cilium.migration/cilium-default=true"
```

Then roll-out the Cilium DaemonSet:

```bash
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --watch
```

> [!NOTE]
> You might want to do a node connectivity test at this point, similar to how it's done in [common.sh](./common.sh)

Finally, get a list of all pods managed by Calico (by filtering IPs using the Calico prefix),
and evict them:

```bash
CALICO_PREFIX="10.233"
kubectl get pods --all-namespaces -o json |
    jq -r --arg ip_test "^${CALICO_PREFIX}" '
      .items[] |
      select(.status.phase == "Running" or .status.pahse == "Pending") |
      select(.status.podIP | test($ip_test)) |
      "\(.metadata.namespace)/\(.metadata.name)"' | xargs ./evict_queue.py
```
