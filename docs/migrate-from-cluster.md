# Migration documentation

## Disclaimer

Migrating a cluster from [ck8s-cluster](https://github.com/elastisys/ck8s-cluster) to [compliantkubernetes-kubespray](https://github.com/elastisys/compliantkubernetes-kubespray) is **NOT** recommended, only do this if you have no other alternative.
If you can, recreating a new cluster is always better.

This has only been tested on CityCloud and might not look the same for other cloud providers

## Steps

1. Set up a kubespray cluster config

    ```bash
    export CK8S_CONFIG_PATH=/path/to/new/config

    bin/ck8s-kubespray init my-new-cluster openstack MYGPGFINGERPRINT
    ```

1. Configure terraform to your liking, but it must match old cluster.

    Some variables to look out for

    ```ini
    cluster_name = "my-cluster" # Same as ${prefix_*c} in tfvars.json
    public_key_path = "/path/to/ssh/key.pub" # Should be ${CK8S_CONFIG_PATH}/ssh/id_rsa_sc.pub
    network_name = "my-cluster-network" # Same as ck8s-cluster (${prefix_*c}-network)
    floatingip_pool = "ext-net" # Same as "external_network_name" in tfvars.json
    external_net = "fba95253-5543-4078-b793-e2de58c31378" # Same as "external_network_id" in tfvars.json

    dns_nameservers = [ "8.8.8.8", "8.8.4.4" ] # Hardcoded in ck8s-cluster
    subnet_cidr = "172.16.0.0/24" # Hardcoded in ck8s-cluster
    ```

1. Move necessary state from ck8s-cluster to kubespray

      Save the IDs of the objects you want to move

    ```ShellSession
    $ pwd
    <ck8s-cluster repo root>/terraform/citycloud
    ```

    ```bash
    export CK8S_CONFIG_PATH=/path/to/old/config

    export TF_VAR_ssh_pub_key_sc="${CK8S_CONFIG_PATH}/ssh/id_rsa_sc.pub"
    export TF_VAR_ssh_pub_key_wc="${CK8S_CONFIG_PATH}/ssh/id_rsa_wc.pub"
    export TF_DATA_DIR="${CK8S_CONFIG_PATH}/.state/.terraform"
    export TF_WORKSPACE=$(yq ".environment_name" ${CK8S_CONFIG_PATH}/config.yaml)

    terraform state show module.service_cluster.module.network.openstack_networking_network_v2.network
    .
    .
    .
      id = "ID-OF-OBJECT"
    .
    .
    .

    terraform state show module.service_cluster.module.network.openstack_networking_router_v2.router
    terraform state show module.service_cluster.module.network.openstack_networking_subnet_v2.subnet
    terraform state show module.service_cluster.module.network.openstack_networking_router_interface_v2.router_interface
    ```

    Import the state to the new terraform with the IDs gathered

    ```ShellSession
    $ pwd
    <compliantkubernetes-kubespray repo root>/kubespray/inventory/${ENVIRONMENT_NAME}
    ```

    ```bash
    export ENVIRONMENT_NAME="name-of-environment"

    terraform import -var-file cluster.tfvars -state ${ENVIRONMENT_NAME}.tfstate -config=../../contrib/terraform/openstack/ module.network.openstack_networking_network_v2.k8s[0] <ID from same resource above>
    terraform import -var-file cluster.tfvars -state ${ENVIRONMENT_NAME}.tfstate -config=../../contrib/terraform/openstack/ module.network.openstack_networking_router_v2.k8s[0] <ID from same resource above>
    terraform import -var-file cluster.tfvars -state ${ENVIRONMENT_NAME}.tfstate -config=../../contrib/terraform/openstack/ module.network.openstack_networking_subnet_v2.k8s[0] <ID from same resource above>
    terraform import -var-file cluster.tfvars -state ${ENVIRONMENT_NAME}.tfstate -config=../../contrib/terraform/openstack/ module.network.openstack_networking_router_interface_v2.k8s[0] <ID from same resource above>
    ```

    If imported correctly the plan of the new machines should only modify the imported resources.
    Nothing should be recreated.

1. Prepare old machines

    Before running kubespray you'll need to make a couple of tweaks on the old machines.

    - All machines

      Remove `/etc/docker/daemon.json`.

      > [!NOTE]
      > This might break docker if it's restarted before running kubespray.

      ```bash
      sudo mv /etc/docker/daemon.json /etc/docker/daemon.json.backup
      ```

    - Masters only

      Create `/var/log/kube-audit`

      ```bash
      sudo mkdir var/log/kube-audit
      ```

      Change ETCD version to `quay.io/coreos/etcd:v3.4.13`

      > [!NOTE]
      > This will restart etcd and if you only have one master it will stop the api server until it's restarted.

      ```bash
      sudo vim /etc/kubernetes/manifest/etcd.yaml
      ```

1. Create inventory for the old cluster

    Add the old machines to the new kubespray config path.

    Remember to add

    ```ini
    [kube-master:vars]
    supplementary_addresses_in_ssl_keys = [ "<LB public IP>", "<LB private IP>" ]
    ```

1. Modify default group_vars to match old setup

    Add the following to the `k8s-cluster` group

    ```yaml
    etcd_deployment_type: kubeadm
    kube_cert_dir: "/etc/kubernetes/pki"
    kube_service_addresses: "10.96.0.0/12"
    kube_pods_subnet: "192.168.0.0/16"

    audit_log_hostpath: "/var/log/kube-audit"
    audit_log_path: "/var/log/kube-audit/kube-apiserver.log"
    audit_policy_file: "/etc/kubernetes/conf/audit-policy.yaml"
    ```

1. Run kubespray on the old machines

    ```bash
    export CK8S_CONFIG_PATH=/path/to/new/config

    bin/ck8s-kubespray run-playbook ${ENVIRONMENT_NAME} cluster.yml
    ```

    Verify that all kubernetes components are running and healthy after this step.

1. Run terraform to set up new machines

    ```ShellSession
    $ pwd
    <compliantkubernetes-kubespray repo root>/kubespray/inventory/${ENVIRONMENT_NAME}
    ```

    ```bash
    terraform apply -var-file cluster.tfvars -state ${ENVIRONMENT_NAME}.tfstate ../../contrib/terraform/openstack/
    ```

1. Add temporary security role between the old and the new machines

    Manually create new rules between the security groups `${ENVIRONMENT_NAME}-cluster` and `${ENVIRONMENT_NAME}-k8s` to allow all traffic

1. Add new workers to kubernetes

    ```bash
    export CK8S_CONFIG_PATH=/path/to/new/config

    bin/ck8s-kubespray run-playbook ${ENVIRONMENT_NAME} facts.yml
    bin/ck8s-kubespray run-playbook ${ENVIRONMENT_NAME} scale.yml --limit=new-worker-X # Add one worker at a time
    ```

    Between each new worker, verify that they get added to kubernetes and get ready

1. Add new masters to kubernetes

    ```bash
    export CK8S_CONFIG_PATH=/path/to/new/config

    bin/ck8s-kubespray run-playbook ${ENVIRONMENT_NAME} cluster.yml --limit=etcd,kube-master -e ignore_assert_errors=yes -e etcd_retries=10
    bin/ck8s-kubespray run-playbook ${ENVIRONMENT_NAME} upgrade-cluster.yml --limit=etcd,kube-master -e ignore_assert_errors=yes -e etcd_retries=10
    ```

    Verify that all the new masters are added and that all kubernetes components are running successfully.

1. Remove old workers from kubernetes

    ```bash
    export CK8S_CONFIG_PATH=/path/to/new/config

    bin/ck8s-kubespray run-playbook ${ENVIRONMENT_NAME} remove-node.yml -e node=old-worker-X # Remove one worker at a time
    ```

1. Remove old masters from kubernetes

    > [!NOTE]
    > Make sure you are not removing more than half the masters.
    > That will make you loose quorum.

    Make sure the master your'e about to remove isn't on the top of the kube_master and etcd group.
    If it is, move it to something else than first place and run:

    ```bash
    export CK8S_CONFIG_PATH=/path/to/new/config

    bin/ck8s-kubespray run-playbook ${ENVIRONMENT_NAME} cluster.yml --limit=etcd,kube-master -e ignore_assert_errors=yes
    ```

    Then you can continue with:

    ```bash
    export CK8S_CONFIG_PATH=/path/to/new/config

    bin/ck8s-kubespray run-playbook ${ENVIRONMENT_NAME} remove-node.yml -e node=old-master-X # Remove one master at a time

    # Update etcd configuration
    bin/ck8s-kubespray run-playbook ${ENVIRONMENT_NAME} cluster.yml --limit=etcd,kube-master -e ignore_assert_errors=yes
    bin/ck8s-kubespray run-playbook ${ENVIRONMENT_NAME} upgrade-cluster.yml --limit=etcd,kube-master -e ignore_assert_errors=yes
    ```

1. Remove migrated state from old terraform

    ```ShellSession
    $ pwd
    <ck8s-cluster repo root>/terraform/citycloud
    ```

    ```bash
    export CK8S_CONFIG_PATH=/path/to/old/config

    export TF_VAR_ssh_pub_key_sc="${CK8S_CONFIG_PATH}/ssh/id_rsa_sc.pub"
    export TF_VAR_ssh_pub_key_wc="${CK8S_CONFIG_PATH}/ssh/id_rsa_wc.pub"
    export TF_DATA_DIR="${CK8S_CONFIG_PATH}/.state/.terraform"
    export TF_WORKSPACE=$(yq r ${CK8S_CONFIG_PATH}/config.yaml environment_name)

    terraform state rm module.service_cluster.module.network.openstack_networking_network_v2.network
    terraform state rm module.service_cluster.module.network.openstack_networking_router_v2.router
    terraform state rm module.service_cluster.module.network.openstack_networking_subnet_v2.subnet
    terraform state rm module.service_cluster.module.network.openstack_networking_router_interface_v2.router_interface
    ```

1. Remove temporary security role between the old and the new machines

    Remove the rules between the security groups `${ENVIRONMENT_NAME}-cluster` and `${ENVIRONMENT_NAME}-k8s` since it isn't needed anymore.

1. Destroy the old resources

    ```ShellSession
    $ pwd
    <ck8s-cluster repo root>/
    ```

    ```bash
    export CK8S_CONFIG_PATH=/path/to/old/config

    go run ./cmd/ck8s destroy --destroy-remote-workspace --cluster <sc|wc>
    ```
