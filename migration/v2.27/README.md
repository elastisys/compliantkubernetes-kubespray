# Upgrade v2.26 to v2.27

## Prerequisites

- [ ] Notify the users (if any) before the upgrade starts;
- [ ] Check if there are any pending changes to the environment;
- [ ] Check the state of the environment, pods, nodes and backup jobs:

    ```bash
    ./compliantkubernetes-apps/bin/ck8s test sc|wc
    ./compliantkubernetes-apps/bin/ck8s ops kubectl sc|wc get pods -A -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,READY-false:status.containerStatuses[*].ready,REASON:status.containerStatuses[*].state.terminated.reason | grep false | grep -v Completed
    ./compliantkubernetes-apps/bin/ck8s ops kubectl sc|wc get nodes
    ./compliantkubernetes-apps/bin/ck8s ops kubectl sc|wc get jobs -A
    velero get backup
    ```

- [ ] Silence the notifications for the alerts. e.g you can use [alertmanager silences](https://prometheus.io/docs/alerting/latest/alertmanager/#silences);

## Steps that can be done before the upgrade - non-disruptive

1. Checkout the new release: `git switch -d v2.27.x-ck8sx`

1. Switch to the correct remote: `git submodule sync`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. Run `bin/ck8s-kubespray upgrade both v2.27 prepare` to update your config.

    > [!NOTE]
    > It is possible to update `wc` and `sc` config separately by replacing `both` when running the `upgrade` command, e.g. the following will only update config for the workload cluster:
    >
    > ```bash
    > bin/ck8s-kubespray upgrade wc v2.27 prepare
    > ```

1. Download the required files on the nodes

    ```bash
    ./bin/ck8s-kubespray run-playbook sc upgrade_cluster.yml -b --tags=download
    ./bin/ck8s-kubespray run-playbook wc upgrade_cluster.yml -b --tags=download
    ```

1. For UpCloud environments, update loadbalancer configuration

    <details>
    <summary>UpCloud environments only</summary>

    It is now possible to create multiple loadbalancers. Even if you are just going to use one loadbalancer, this config update is still needed.

    Update the loadbalancer configuration in accordance to the following diff:

    ```diff
    - loadbalancer_legacy_network = copy-me # Copy whatever value you have in your cluster
    - loadbalancer_plan = "copy-me" # Copy whatever value you have in your cluster
      loadbalancers = {
    +   "public" = {
    +     plan = "<Copied value from loadbalancer_plan>"
    +     legacy_network = <Copied value from loadbalancer_legacy_network>
    +     public_network = true
    +     private_network = true
    +     targets = {
            "http" : {
              "proxy_protocol" : false,
              "port" : 80,
              "target_port" : 80,
    +         "listen_public" : true
    +         "listen_private" : false
              "backend_servers" : [
                "worker-0",
              ]
            },
            "https" : {
              "proxy_protocol" : false,
              "port" : 443,
              "target_port" : 443,
    +         "listen_public" : true
    +         "listen_private" : false
              "backend_servers" : [
                "worker-0",
              ]
            },
            "master-api" : {
              "proxy_protocol" : false,
              "port" : 6443,
              "target_port" : 6443,
    +         "listen_public" : true
    +         "listen_private" : false
              "backend_servers" : [
                "control-plane-1",
              ]
            }
          }
        },
    + }
    ```

    The migration script takes the name of the loadbalancer to migrate as an argument.
    This should be `public` if you followed the change above.

    ```bash
    export CK8S_CONFIG_PATH=...
    export CK8S_CLUSTER=<sc|wc|both>
    ./migration/v2.27/apply/00-migrate-upcloud-loadbalancer-state.sh <name of lb>
    ```

    Verify the terraform to update state.
    The expected difference from `terraform plan` should be that the loadbalancer should be updated in-place with a new name and the output `loadbalancer_domain` object will become a list of loadbalancers.

    ```bash
    # Source credentials
    CK8S_KUBESPRAY_PATH=/path/to/compliantkubernetes-kubespray
    terraform -chdir="${CK8S_KUBESPRAY_PATH}/kubespray/contrib/terraform/upcloud/" plan -var "UPCLOUD_PASSWORD=${UPCLOUD_PASSWORD}" -var "UPCLOUD_USERNAME=${UPCLOUD_USERNAME}" -var-file="${CK8S_CONFIG_PATH}/sc-config/cluster.tfvars" -state="${CK8S_CONFIG_PATH}/sc-config/terraform.tfstate" -var="inventory_file=${CK8S_CONFIG_PATH}/sc-config/inventory.ini"
    terraform -chdir="${CK8S_KUBESPRAY_PATH}/kubespray/contrib/terraform/upcloud/" plan -var "UPCLOUD_PASSWORD=${UPCLOUD_PASSWORD}" -var "UPCLOUD_USERNAME=${UPCLOUD_USERNAME}" -var-file="${CK8S_CONFIG_PATH}/wc-config/cluster.tfvars" -state="${CK8S_CONFIG_PATH}/wc-config/terraform.tfstate" -var="inventory_file=${CK8S_CONFIG_PATH}/wc-config/inventory.ini"
    ```

    </details>

## Upgrade steps

These steps will cause disruptions in the environment.

1. For UpCloud environments, update loadbalancer configuration

    <details>
    <summary>UpCloud environments only</summary>

    Apply terraform to update state.

    ```bash
    # Source credentials
    CK8S_KUBESPRAY_PATH=/path/to/compliantkubernetes-kubespray
    terraform -chdir="${CK8S_KUBESPRAY_PATH}/kubespray/contrib/terraform/upcloud/" apply -var "UPCLOUD_PASSWORD=${UPCLOUD_PASSWORD}" -var "UPCLOUD_USERNAME=${UPCLOUD_USERNAME}" -var-file="${CK8S_CONFIG_PATH}/sc-config/cluster.tfvars" -state="${CK8S_CONFIG_PATH}/sc-config/terraform.tfstate" -var="inventory_file=${CK8S_CONFIG_PATH}/sc-config/inventory.ini"

    terraform -chdir="${CK8S_KUBESPRAY_PATH}/kubespray/contrib/terraform/upcloud/" apply -var "UPCLOUD_PASSWORD=${UPCLOUD_PASSWORD}" -var "UPCLOUD_USERNAME=${UPCLOUD_USERNAME}" -var-file="${CK8S_CONFIG_PATH}/wc-config/cluster.tfvars" -state="${CK8S_CONFIG_PATH}/wc-config/terraform.tfstate" -var="inventory_file=${CK8S_CONFIG_PATH}/wc-config/inventory.ini"
    ```

    </details>

1. Upgrade the cluster to a new kubernetes version:

    ```bash
    ./bin/ck8s-kubespray run-playbook sc upgrade_cluster.yml -b -e skip_downloads=true
    ./bin/ck8s-kubespray run-playbook wc upgrade_cluster.yml -b -e skip_downloads=true
    ```

## Postrequisite

- [ ] Check the state of the environment, pods and nodes:

    ```bash
    ./compliantkubernetes-apps/bin/ck8s test sc|wc
    ./compliantkubernetes-apps/bin/ck8s ops kubectl sc|wc get pods -A -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,READY-false:status.containerStatuses[*].ready,REASON:status.containerStatuses[*].state.terminated.reason | grep false | grep -v Completed
    ./compliantkubernetes-apps/bin/ck8s ops kubectl sc|wc get nodes
    ```

- [ ] Enable the notifications for the alerts;
- [ ] Notify the users (if any) when the upgrade is complete;

> [!NOTE]
> Additionally it is good to check:
>
> - if any alerts generated by the upgrade didn't close.
> - if you can login to Grafana, Opensearch or Harbor.
> - if you can see fresh metrics and logs.
