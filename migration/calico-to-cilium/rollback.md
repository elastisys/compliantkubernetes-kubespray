# I want Calico back

1. Switch the networking plugin back to Calico

    ```bash
    yq -i '.kube_network_plugin = "calico"' "${CK8S_CONFIG_PATH}/${TARGET_CLUSTER}-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml"
    ../../bin/ck8s-kubespray apply ${TARGET_CLUSTER} --tags download,network
    ```

1. Restore the Calico CNI config in favor of Cilium

    ```bash
    cilium-cli uninstall
    ../../bin/ck8s-kubespray run-playbook ${TARGET_CLUSTER} ../../playbooks/rollback_cilium.yml -b
    ```

1. Migrate nodes one by one back to Calico

- Get the list of worker nodes and migrate them one by one, passing the node name as argument to the `./20-migrate-node.sh` script:

    ```bash
    kubectl get nodes --no-headers -o custom-columns=":metadata.name" |
      grep -v 'control-plane' |
      xargs -rt -I{} --interactive ./20-migrate-node.sh {} --rollback
    ```

- Get the list of control plane nodes and migrate them one by one, passing the node name as argument to the `./20-migrate-node.sh` script:

    ```bash
    kubectl get nodes --no-headers -o custom-columns=":metadata.name" |
      grep 'control-plane' |
      xargs -rt -I{} --interactive ./20-migrate-node.sh {} --rollback
    ```

    >[!NOTE]
    > Notice the `--rollback` argument to the `20-migrate-node.sh` script

1. (Optional) Nuclear option: evict all pods

- If feeling adventurous, you can skip steps 3 & 4, and just evict all pods with Cilium IPs:

  ```bash
  CILIUM_PREFIX="10.235"
  kubectl get pods --all-namespaces -o json |
      jq -r --arg ip_test "^${CILIUM_PREFIX}" '
        .items[] |
        select(.status.phase == "Running" or .status.pahse == "Pending") |
        select(.status.podIP | test($ip_test)) |
        "\(.metadata.namespace)/\(.metadata.name)"' | xargs ./evict_queue.py
  ```
