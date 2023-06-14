# Upgrade v2.20.0-ck8sx to v2.21.0-ck8s1

## Prerequisites

> **_NOTE:_** This version upgrades Kubernetes to `v1.25` in which Pod Security Policies (PSPs) are removed. You should not upgrade to this version if you are using PSPs. To deploy [Compliant Kubernetes Apps](https://github.com/elastisys/compliantkubernetes-apps) on this version it needs to be on a compatible version which depends on [this issue](https://github.com/elastisys/compliantkubernetes-apps/issues/1218).

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

1. Checkout the new release: `git switch -d v2.21.0-ck8s1`

1. Switch to the correct remote: `git submodule sync`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. Run the following to create the new config file for both sc and wc.

    ```console
    export CK8S_KUBESPRAY_PATH=/path/to/compliantkubernetes-kubespray

    for cluster in "sc" "wc"; do
        cp "${CK8S_KUBESPRAY_PATH}"/config/common/group_vars/all/ck8s-kubespray-general.yaml \
        "${CK8S_CONFIG_PATH}"/"${cluster}"-config/group_vars/all/ck8s-kubespray-general.yaml
    done
    ```

1. Run `bin/ck8s-kubespray upgrade v2.21 prepare` to update your config.

    Note: This enables NTP service and with multiple NTP servers, specifically in Sweden.
    You can visit [www.ntppool.org](https://www.ntppool.org/zone/@) to find other ntp pools if you are in other parts of the world, and edit `ntp_servers` in `group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` manually.

1. Download the required files on the nodes

    ```bash
    ./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b --tags=download
    ./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b --tags=download
    ```

## Upgrade steps

These steps will cause disruptions in the environment.

1. **If the environment is running `rook-ceph`**

    For both `sc` and `wc`:

    1. Apply PSA labels to the namespace:

        ```bash
        kubectl label namespace rook-ceph pod-security.kubernetes.io/audit=privileged
        kubectl label namespace rook-ceph pod-security.kubernetes.io/enforce=privileged
        kubectl label namespace rook-ceph pod-security.kubernetes.io/warn=privileged
        ```

    1. Apply bypass Kubernetes PSP:

        ```bash
        ./migration/v2.21/apply/bypass-k8s-psp.sh execute
        ```

    1. Upgrade the operator to remove PSP and associated RBAC

        ```bash
        namespace="rook-ceph"
        release_name="rook-ceph"
        chart="rook-release/rook-ceph"
        chart_version="<set chart version>" # Can be fetched by running `helm list -n rook-ceph`
        helm repo add rook-release https://charts.rook.io/release
        helm diff upgrade --namespace "${namespace}" "${release_name}" "${chart}" --version "${chart_version}" --values "./rook/operator-values.yaml"
        helm upgrade --namespace "${namespace}" "${release_name}" "${chart}" --version "${chart_version}" --values "./rook/operator-values.yaml" --wait
        ```

1. Upgrade the cluster to a new kubernetes version:

    ```bash
    ./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b --skip-tags=download
    ./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b --skip-tags=download
    ```

1. **For Openstack environments only**

    1. Migrate terraform state.

        ```bash
        ./migration/v2.21/apply/migrate-terraform-openstack-user-data.sh
        ```

        The script generated a `terraform-temp.tfstate` file with some updated values and then ran "terraform plan" with this temporary state file.
        If terraform did not show any unexpected changes, you can run the following snippet to update the original state file for WC & SC:

        ```bash
        for CLUSTER in sc wc; do
            pushd ${CK8S_CONFIG_PATH}/${CLUSTER}-config > /dev/null
            mv terraform-temp.tfstate terraform.tfstate
            popd > /dev/null
        done
        ```

    1. Lastly apply the new state to update the modules (there should be no diff in the terraform output here)

        ```bash
        ./migration/v2.21/apply/apply-new-state.sh
        ```

1. **If the environment is running `rook-ceph`**

    For both `sc` and `wc`, clean up bypass Kubernetes PSP:

    ```bash
    ./migration/v2.21/apply/bypass-k8s-psp.sh clean
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

> **_Note:_** Additionally it is good to check:

- if any alerts generated by the upgrade didn't close.
- if you can login to Grafana, Opensearch or Harbor.
- if you can see fresh metrics and logs.
