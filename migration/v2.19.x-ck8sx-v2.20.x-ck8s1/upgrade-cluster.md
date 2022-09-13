# Upgrade v2.19.x-ck8sx to v2.20.x-ck8s1

1. Checkout the new release: `git checkout v2.20.x-ck8s1`

1. Switch to the correct remote: `git submodule sync`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. set the values for `kubeconfig_cluster_name` in both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` to the corresponding name like below:

    ```yaml
    kubeconfig_cluster_name: <CHANGE-ME-ENVIRONMENT-NAME-sc>
    kubeconfig_cluster_name: <CHANGE-ME-ENVIRONMENT-NAME-wc>
    ```

1. Upgrade the cluster to a new kubernetes version:

    ```bash
    ./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b
    ./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b
    ```

1. generate updated kubeconfigs:

    ```bash
    ./bin/ck8s-kubespray run-playbook sc ../playbooks/kubeconfig.yml -b
    ./bin/ck8s-kubespray run-playbook wc ../playbooks/kubeconfig.yml -b
    ```
