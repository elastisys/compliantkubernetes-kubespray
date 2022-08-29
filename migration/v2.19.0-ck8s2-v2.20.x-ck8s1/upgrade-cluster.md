# Upgrade v2.19.0-ck8s2 to v2.20.x-ck8s1

1. Checkout the new release: `git checkout v2.20.x-ck8s1`

1. Switch to the correct remote: `git submodule sync`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. Add the following snippet at the end of both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml`

    ```diff
    +kube_profiling: false

    +kube_scheduler_bind_address: 127.0.0.1
    +kube_kubeadm_scheduler_extra_args:
    +    profiling: false

    +kube_controller_manager_bind_address: 127.0.0.1
    ```

1. Upgrade your service cluster by running `./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b`.

1. Upgrade your workload cluster by running `./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b`.
