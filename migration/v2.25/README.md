# Upgrade v.2.24 to v2.25

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

1. Checkout the new release: `git switch -d v2.25.x-ck8sx`

1. Switch to the correct remote: `git submodule sync`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. Run `bin/ck8s-kubespray upgrade both v2.25 prepare` to update your config.

    > [!NOTE]
    > It is possible to update `wc` and `sc` config separately by replacing `both` when running the `upgrade` command, e.g. the following will only update config for the workload cluster:
    >
    > ```bash
    > bin/ck8s-kubespray upgrade wc v2.25 prepare
    > ```

> [!NOTE]
> The prepare step ran earlier will set the `ntp_filter_interface` to `true` and the default interface ntp listens on is `ens3` but if the underlying host uses a different interface, add that instead of ens3 under `ntp_interfaces`

> [!NOTE]
> The following step for setting the Calico version in the config can be skipped on `v2.25.0-ck8s4`.

1. Manually add the following snippet at the end of both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml`:

  ```yaml
  calico_version: v3.27.4
  calicoctl_binary_checksums:
    amd64:
      v3.27.4: 84f2bd29ef7b06e85a2caf0b6c6e0d3da5ab5264d46b360e6baaf49bbc3b957d
  calico_crds_archive_checksums:
    v3.27.4: 5f6ac510bd6bd8c14542afe91f7dbcf2a846dba02ae3152a3b07a1bfdea96078
  ```

1. Download the required files on the nodes

    ```bash
    ./bin/ck8s-kubespray run-playbook sc upgrade_cluster.yml -b --tags=download
    ./bin/ck8s-kubespray run-playbook wc upgrade_cluster.yml -b --tags=download
    ```

1. Run `migration/v2.25/prepare/20-change-topology-constraints.sh` **or** manually add the following snippet at the end of both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml`

    ```yaml
    kube_scheduler_profiles:
      - schedulerName: default-scheduler
        pluginConfig:
          - name: PodTopologySpread
            args:
              defaultingType: List
              defaultConstraints:
                - maxSkew: 1
                  topologyKey: kubernetes.io/hostname
                  whenUnsatisfiable: ScheduleAnyway
                - maxSkew: 1
                  topologyKey: topology.kubernetes.io/zone
                  whenUnsatisfiable: ScheduleAnyway

    ```

## Upgrade steps

These steps will cause disruptions in the environment.

1. Upgrade the cluster to a new kubernetes version:

    ```bash
    ./bin/ck8s-kubespray run-playbook sc upgrade_cluster.yml -b -e skip_downloads=true
    ./bin/ck8s-kubespray run-playbook wc upgrade_cluster.yml -b -e skip_downloads=true
    ```

1. Restart `kube-scheduler` on the control plane nodes:

    ```bash
    export TERRAFORM_STATE_ROOT="${CK8S_CONFIG_PATH}/sc-config"
    ansible -i "${CK8S_CONFIG_PATH}/sc-config/inventory.ini" kube_control_plane -b -m shell -a "crictl pods  --name 'kube-scheduler*' -q | xargs -I% bash -c 'crictl stopp % && crictl rmp %'"
    export TERRAFORM_STATE_ROOT="${CK8S_CONFIG_PATH}/wc-config"
    ansible -i "${CK8S_CONFIG_PATH}/wc-config/inventory.ini" kube_control_plane -b -m shell -a "crictl pods  --name 'kube-scheduler*' -q | xargs -I% bash -c 'crictl stopp % && crictl rmp %'"
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
