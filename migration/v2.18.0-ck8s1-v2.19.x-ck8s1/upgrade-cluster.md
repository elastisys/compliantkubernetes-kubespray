# Upgrade v2.18.0-ck8s1 to v2.19.x-ck8s1

1. Checkout the new release: `git checkout v2.19.x-ck8s1`

1. Switch to the correct remote: `git submodule sync`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. add the following snippet at the end of both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml`

    ```yaml
    kubelet_config_extra_args:
    imageGCHighThresholdPercent: 75
    imageGCLowThresholdPercent: 70
    ```

1. Upgrade your cluster by running `./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b`.

1. Upgrade your cluster by running `./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b`.

1. After the upgrade, if you want to start using containerd follow [this guide](https://kubespray.io/#/docs/upgrades/migrate_docker2containerd) to migrate or set `container_manager: containerd` to `${CK8S_CONFIG_PATH}/{wc,sc}-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and run

```bash
./bin/ck8s-kubespray run-playbook {sc|wc} ../migration/v2.18.0-ck8s1-v2.19.x-ck8s1/migrate-to-containerd.yml -b
```

**NOTE**: If you are running [Compliant Kubernetes Apps](https://github.com/elastisys/compliantkubernetes-apps). Make sure you're running a version that has support for conatinerd.
