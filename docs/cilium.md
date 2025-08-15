# Cilium as network plugin

## Creating a Cilium cluster

To create a new cluster that uses `cilium` as its network plugin, set the following keys in `group_vars/all/k8s_cluster/ck8s-k8s-cluster.yaml`:

```yaml
# Set cilium as the network plugin
kube_network_plugin: cilium

# Pin the cilium chart version
cilium_version: "1.17.5"

# Tell cilium to store identities in CRDs rather than try talking to etcd directly
cilium_identity_allocation_mode: "crd"

# Enable hubble (needed for some of the metrics)
cilium_enable_hubble: true
cilium_hubble_install: true
cilium_hubble_tls_generate: true

# See https://github.com/kubernetes-sigs/kubespray/issues/12276
kube_owner: root
```

## Configuring Cilium

Cilium configuration itself lives in `group_vars/all/k8s_cluster/ck8s-cilium.yaml`.

It closely mimics the [Cilium configuration block that from CAPI](https://github.com/elastisys/ck8s-cluster-api/blob/e2ce0c947c773efa1e1b8e78fcdc2c1f50f484d5/config/base-values.yaml#L119-L156).

For new clusters the file should be copied automatically to the configuration directory during the `init` step.

We don't yet have a migration plan for existing clusters to switch CNIs, but should you desire to experiment you'll need to copy the file manually.

## Development tips

After a successful initial run of Kubespray, if you just want to test out configuration changes you can speed up subsequent runs by a huge factor by skipping certain tags:

    ./bin/ck8s-kubespray apply sc --skip-tags "bootstrap-os,preinstall,container-engine,download,node"
