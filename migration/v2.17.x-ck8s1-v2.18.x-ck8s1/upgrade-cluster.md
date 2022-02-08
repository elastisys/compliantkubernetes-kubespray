# Upgrade v2.16.0-ck8s1 to v2.17.x-ck8s1

1. Checkout the new release: `git switch v2.18.0-ck8s1`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. Find `use_server_groups` in cluster.tfvars:
    1. If set to `true`:
        1. Add `master_server_group_policy` and `node_server_group_policy` and set both to `anti-affinity` otherwise the worker nodes will be recreated.
    1. If set to `false` or missing:
        1. Add `master_server_group_policy` and `node_server_group_policy` and set both to `""` otherwise they will be recreated.

1. Run terraform plan `terraform plan -var-file cluster.tfvars ${CK8S_KUBESPRAY_REPO}/kubespray/contrib/terraform/<cloudprovider>`
    For openstack clusters, there might be a `openstack_compute_servergroup_v2` with name `k8s-etcd-srvgrp` that gets deleted if you used server groups and didn't add the `etcd_server_group_policy`.
    This is expected since we don't use separate etcd nodes.
    If nodes are recreated, make sure to check previous step.

1. Run terraform `terraform apply -var-file cluster.tfvars ${CK8S_KUBESPRAY_REPO}/kubespray/contrib/terraform/<cloudprovider>`

1. Add `cinder_tolerations` to clusters that needs it.

1. If you want to upgrade and start using containerd, follow [this guide](https://kubespray.io/#/docs/upgrades/migrate_docker2containerd) to migrate.
    NOTE: If you are running Compliant Kubernetes. Make sure you're running a version that has support for conatinerd.

    Else you can add `container_manager: docker` to end of both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml`

1. Upgrade your service cluster by running `./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b`.

1. Upgrade your workload cluster by running `./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b`.
