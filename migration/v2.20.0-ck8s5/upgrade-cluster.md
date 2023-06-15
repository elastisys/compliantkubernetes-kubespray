# Upgrade v2.20.0-ck8s3 to v2.20.0-ck8s5

## Prerequisites

As this patch version only includes config changes that are not applied to the cluster, there are no prerequisites.

## Steps that can be done before the upgrade - non-disruptive

1. Checkout the new release: `git switch -d v2.20.0-ck8s5`

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

1. Run `bin/ck8s-kubespray upgrade v2.20.0-ck8s5 prepare` to update your config.

## Upgrade steps

No upgrade steps.

## Postrequisite

- [ ] Check in `${CK8S_CONFIG_PATH}/<sc|wc>-config/group_vars/all/ck8s-kubespray-general.yaml` that the version number is correct.
