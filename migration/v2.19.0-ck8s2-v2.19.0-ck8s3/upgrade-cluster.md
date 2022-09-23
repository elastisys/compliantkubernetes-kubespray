# Upgrade v2.19.0-ck8s2 to v2.19.0-ck8s3 Only needed for upcloud

1. Checkout the new release: `git checkout v2.19.0-ck8s3`

1. Switch to the correct remote: `git submodule sync`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. upcloud environments remove or update storage class specification
    The new default in the config is the following

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

1. Upgrade the cluster to a new kubernetes version:

    ```bash
    ./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b
    ./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b
    ```
