# Upgrade v2.18.0-ck8s1 to v2.19.x-ck8s1

1. Checkout the new release: `git checkout v2.19.x-ck8s1`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. add the following snippet at the end of both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml`

    ```yaml
    kubelet_config_extra_args:
    imageGCHighThresholdPercent: 75
    imageGCLowThresholdPercent: 70
    ```

1. Upgrade your cluster by running `./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b`.

1. Upgrade your cluster by running `./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b`.
