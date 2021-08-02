# Upgrade v2.15.0-ck8s1 to v2.16.0-ck8s1

1. Checkout the new release: `git checkout v2.16.0-ck8s1`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. Kubespray has in 2.16.0 updated the name of their groups.
    You must manually update the following:

    - If you are not using dynamic inventories (e.g. for Exoscale), change the following groups in your inventory file (`inventory.ini`): kube-master to kube_control_plane, kube-node to kube_node, and k8s-cluster to k8s_cluster.
    See `config/inventory.ini` for an example.

    - If you are using dynamic inventories, you may have to run `terraform apply` to update your terraform state with new metadata about these new group names.

    - Update any folders inside `group_vars/` to match the new names for the groups mentioned above (e.g. change k8s-cluster to k8s_cluster)

1. SSH into each node and run the following:

    ```bash
    sudo /bin/apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" install 'containerd.io=1.4.4-1' 'docker-ce-cli=5:19.03.15~3-0~ubuntu-focal' 'docker-ce=5:19.03.15~3-0~ubuntu-focal'
    ```

    If nothing gets downgraded on the first node you try this on, you can skip doing it on the other ones in the cluster.

1. Upgrade you cluster by running `./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b`.
    Note that this will also upgrade Kubernetes to v1.20.7 (unless you have another version pinned).
