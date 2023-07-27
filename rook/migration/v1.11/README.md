# Upgrade rook-ceph to v1.11.x

> **Warning**: Upgrade only supported from v1.10.x.

## Prerequisites

- [ ] Check the state of rook-ceph so it is healthy before you begin:

  ```bash
  helm -n rook-ceph list --all
  # should show all deployed
  kubectl -n rook-ceph get jobs
  # should show all completed
  kubectl -n rook-ceph get pods
  # should show all running or completed
  kubectl -n rook-ceph get cephclusters
  # should show PHASE = Ready and HEALTH = HEALTH_OK
  ```

## Prepare upgrade - *non-disruptive*

> *Done before maintenance window*

### Helmfile migration

> **Warning**: This should be followed from v1.10.x to migrate to helmfile, and expects that rook-ceph is setup with the previous method.
>
> It assumes that the previous operator values and manifests have been copied over to "${CK8S_CONFIG_PATH}/rook/"

1. Migrate configuration:

    ```bash
    ./migration/v1.11/prepare/configure.sh
    ```

    Set a [cluster preset](../../helmfile.d/values/cluster-presets) at `.commons.cluster.preset` that best matches the current setup.

1. Update configuration:

    ```bash
    # with kubeconfig pointing to service cluster
    ./scripts/autoconfig.sh service

    # with kubeconfig pointing to workload cluster
    ./scripts/autoconfig.sh workload
    ```

1. Diff:

    ```bash
    # with kubeconfig pointing to service cluster
    ./migration/v1.11/prepare/diff.sh service

    # with kubeconfig pointing to workload cluster
    ./migration/v1.11/prepare/diff.sh workload
    ```

    Ensure that the are no major changes.
    New default values and resource requests and limits are expected.

## Apply upgrade - *disruptive*

> *Done during maintenance window*

### Helmfile migration

> **Warning**: This should be followed from v1.10.x to migrate to helmfile, and expects that rook-ceph is setup with the previous method.
>
> It assumes that the previous operator values and manifests have been copied over to "${CK8S_CONFIG_PATH}/rook/"

1. Disable monitoring, networkpolicies and podsecuritypolicies for rook-ceph in apps!

    These will now be provided from here so they must be removed else they will be in conflict.

1. Annotate and label resources:

    ```bash
    # with kubeconfig pointing to service cluster
    ./migration/v1.11/apply/annotate-label.sh service

    # with kubeconfig pointing to workload cluster
    ./migration/v1.11/apply/annotate-label.sh workload
    ```

1. Remove old toolbox:

    ```bash
    # with kubeconfig pointing to service cluster
    kubectl -n rook-ceph delete -f "${CK8S_CONFIG_PATH}/rook/toolbox-deploy.yaml"
    # or
    kubectl -n rook-ceph delete deployment rook-ceph-tools

    # with kubeconfig pointing to workload cluster
    kubectl -n rook-ceph delete -f "${CK8S_CONFIG_PATH}/rook/toolbox-deploy.yaml"
    # or
    kubectl -n rook-ceph delete deployment rook-ceph-tools
    ```

1. Apply new monitoring and policies:

    ```bash
    # with kubeconfig pointing to service cluster
    helmfile -e service -l app=dashboards -l app=rules -l app=netpol -l app=psp apply

    # with kubeconfig pointing to workload cluster
    helmfile -e workload -l app=dashboards -l app=rules -l app=netpol -l app=psp apply
    ```

1. Adopt namespace:

    ```bash
    # with kubeconfig pointing to service cluster
    helmfile -e service -l app=namespace apply
    helmfile -e service -l app=namespace sync --args --force

    # with kubeconfig pointing to workload cluster
    helmfile -e workload -l app=namespace apply
    helmfile -e workload -l app=namespace sync --args --force
    ```

1. Upgrade operator:

    > **Warning**: This will cause new rollouts of all rook-ceph components.

    ```bash
    # with kubeconfig pointing to service cluster
    helmfile -e service -l app=operator diff
    helmfile -e service -l app=operator apply

    kubectl get po -n rook-ceph -w
    kubectl -n rook-ceph get cephclusters -w
    # wait for condition PHASE = Ready and HEALTH = HEALTH_OK, the pods will restart quite slow

    # with kubeconfig pointing to workload cluster
    helmfile -e workload -l app=operator diff
    helmfile -e workload -l app=operator apply

    kubectl get po -n rook-ceph -w
    kubectl -n rook-ceph get cephclusters -w
    # wait for condition PHASE = Ready and HEALTH = HEALTH_OK, the pods will restart quite slow
    ```

1. Upgrade cluster:

    > **Warning**: This will cause new rollouts of all rook-ceph components.

    ```bash
    # with kubeconfig pointing to service cluster
    helmfile -e service -l app=cluster apply
    helmfile -e service -l app=cluster sync --args --force

    kubectl get po -n rook-ceph -w
    kubectl -n rook-ceph get cephclusters -w
    # wait for condition PHASE = Ready and HEALTH = HEALTH_OK, the pods will restart quite slow

    # with kubeconfig pointing to workload cluster
    helmfile -e workload -l app=cluster apply
    helmfile -e workload -l app=cluster sync --args --force

    kubectl get po -n rook-ceph -w
    kubectl -n rook-ceph get cephclusters -w
    # wait for condition PHASE = Ready and HEALTH = HEALTH_OK, the pods will restart quite slow
    ```

1. Final apply:

    ```bash
    # with kubeconfig pointing to service cluster
    helmfile -e service diff
    helmfile -e service apply

    # with kubeconfig pointing to workload cluster
    helmfile -e workload diff
    helmfile -e workload apply
    ```

## Postrequisites

- [ ] Check the state of rook-ceph so it is healthy before you end:

  ```bash
  helm -n rook-ceph list --all
  # should show all deployed
  kubectl -n rook-ceph get jobs
  # should show all completed
  kubectl -n rook-ceph get pods
  # should show all running or completed
  kubectl -n rook-ceph get cephclusters
  # should show PHASE = Ready and HEALTH = HEALTH_OK
  ```
