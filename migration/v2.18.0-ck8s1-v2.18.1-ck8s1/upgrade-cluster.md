# Upgrade v2.18.0-ck8s1 to v2.18.1-ck8s1

1. Checkout the new release: `git switch v2.18.1-ck8s1`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. Update git remote for kubespray submodule: `git submodule sync`

1. Add the following to `${CK8S_CONFIG_PATH}/{wc,sc}-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml`

    ```yaml
    etcd_version: v3.5.3
    etcd_binary_checksums:
      amd64: e13e119ff9b28234561738cd261c2a031eb1c8688079dcf96d8035b3ad19ca58
    ```

1. Upgrade your service cluster by running `./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b`.

1. Upgrade your workload cluster by running `./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b`.
