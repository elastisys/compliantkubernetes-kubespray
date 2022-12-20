# Upgrade v2.19.x-ck8sx to v2.20.x-ck8s1

## Preparations

These steps will not disrupt the environment and can be done ahead of a maintenance window.

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

    +calico_pool_blocksize: 24

    +kubelet_secure_addresses: >-
    +  {%- for host in groups['kube_control_plane'] -%}
    +    {{ hostvars[host]['ip'] | default(fallback_ips[host]) }}{{ ' ' if not loop.last else '' }}
    +  {%- endfor -%}

    +containerd_version: 1.6.12
    +containerd_archive_checksums:
    +  amd64:
    +    1.6.12: a56c39795fd0d0ee356b4099a4dfa34689779f61afc858ef84c765c63e983a7d
    ```

1. set the values for `kubeconfig_cluster_name` in both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` to the corresponding name like below:

    ```yaml
    kubeconfig_cluster_name: <CHANGE-ME-ENVIRONMENT-NAME-sc>
    kubeconfig_cluster_name: <CHANGE-ME-ENVIRONMENT-NAME-wc>
    ```

1. For upcloud environments, remove or update storage class specification.
    The new default in the config is the following:

    ```
    storage_classes:
       - name: standard
         is_default: true
         expand_persistent_volumes: true
         parameters:
           tier: maxiops
       - name: hdd
         is_default: false
         expand_persistent_volumes: true
         parameters:
           tier: hdd
    ```

    Remove or update the `storage_classes` in both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster-upcloud.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster-upcloud.yaml` to work with the new format

    Update example:
    Old format:

    ```
     expand_persistent_volumes: true
     parameters:
         tier: maxiops
      storage_classes:
            - name: standard
              is_default: true
    ```

    To new format

    ```diff
    - expand_persistent_volumes: true
    - parameters:
    -     tier: maxiops
      storage_classes:
            - name: standard
              is_default: true
    +         expand_persistent_volumes: true
    +         parameters:
    +             tier: maxiops
    ```

## Disruptive steps

These steps will cause disruptions in the environment.

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
