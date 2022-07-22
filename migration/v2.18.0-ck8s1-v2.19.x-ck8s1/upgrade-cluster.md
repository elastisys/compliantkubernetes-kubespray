# Upgrade v2.18.0-ck8s1 to v2.19.x-ck8s1

1. Checkout the new release: `git checkout v2.19.x-ck8s1`

> The new kubespray version does not work with older terraform setups. If terraform actions are needed revert to v2.18.1 or migrate the terraform state once this [issue](https://github.com/elastisys/compliantkubernetes-kubespray/issues/176) is closed.

1. Switch to the correct remote: `git submodule sync`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. add the following snippet at the end of both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml`

    ```yaml
    kubelet_config_extra_args:
    imageGCHighThresholdPercent: 75
    imageGCLowThresholdPercent: 70
    ```

1. remove any snippet specifying etc version in  `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` or in any other place

    ```diff
    -etcd_version: v3.5.3
    -etcd_binary_checksums:
    -amd64: e13e119ff9b28234561738cd261c2a031eb1c8688079dcf96d8035b3ad19ca58
    ```

1. add the following snippet at the end of both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml`

    ```yaml
    calico_ipip_mode: 'Always'
    calico_vxlan_mode: 'Never'
    calico_network_backend: 'bird'
    ```

    If vxlan is preferred over ipip, please refer to this [document](https://github.com/kubernetes-sigs/kubespray/blob/v2.19.0/docs/calico.md#config-encapsulation-for-cross-server-traffic)

1. replace the following snippet in both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster-openstack.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster-openstack.yaml`

    ```diff
    -etcd_kubeadm_enabled: true
    +etcd_deployment_type: kubeadm
    ```

1. Clear the old ansible versions before running the upgrade

    ```console
    ./migration/v2.18.0-ck8s1-v2.19.x-ck8s1/clear-old-ansible-versions.sh
    ```

1. Upgrade time, the sc cluster takes about 90 minutes.

    During the upgrade keep an eye on the nodes. Nodes that are in `notReady` and have the events

    ```console
    kubectl describe nodes <node>
    ....
    Warning  InvalidDiskCapacity      7s     kubelet     invalid capacity 0 on image filesystem
    ```

    needs a reboot. It is a bug that is fixed in [v1.24.0](https://github.com/kubernetes/kubernetes/pull/108325)

1. Upgrade your cluster by running `./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b`.

1. Upgrade your cluster by running `./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b`.

1. After the upgrade, if you want to start using containerd follow [this guide](https://kubespray.io/#/docs/upgrades/migrate_docker2containerd) to migrate or set `container_manager: containerd` to `${CK8S_CONFIG_PATH}/{wc,sc}-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and run

```bash
./bin/ck8s-kubespray run-playbook {sc|wc} ../migration/v2.18.0-ck8s1-v2.19.x-ck8s1/migrate-to-containerd.yml -b
```

**NOTE**: If you are running [Compliant Kubernetes Apps](https://github.com/elastisys/compliantkubernetes-apps). Make sure you're running a version that has support for conatinerd.

**NOTE**: Don't forget to do migration steps in [../v2.19.0-ck8s1-v2.19.0-ck8s2](https://github.com/elastisys/compliantkubernetes-kubespray/tree/main/migration/v2.19.0-ck8s1-v2.19.0-ck8s2) folder if you are upgrading from `v2.18.0-ck8s1` to `v2.19.0-ck8s2`.
