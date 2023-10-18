# Upgrade v2.21.0-ck8sx to v2.22.0-ck8sx

1. Checkout the new release: `git checkout v2.22.0-ck8sx`

1. Switch to the correct remote: `git submodule sync`

1. Update the kubespray submodule: `git submodule update --init --recursive`

## Disruptive steps

These steps will cause disruptions in the environment.

1. Upgrade the cluster to a new kubernetes version:

    ```bash
    ./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b
    ./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b
    ```

## Update terraform state for Exoscale environments

1. Add the type of `family` each compute instance is part of in `cluster.tfvars`:

    The nodes will most likely be part of `standard`.
    You can check this by looking at the `type`, `family.size`, in the following output:

    ```console
    exo compute instance list
    ┼──────────────────────────────────────┼──────────────────────────────────┼──────────┼──────────────────────┼─────────────────┼─────────┼
    │                  ID                  │               NAME               │   ZONE   │         TYPE         │   IP ADDRESS    │  STATE  │
    ┼──────────────────────────────────────┼──────────────────────────────────┼──────────┼──────────────────────┼─────────────────┼─────────┼
    │ 05559c97-fe3d-465c-bf83-759beaad2beb │ worker-name                      │ ch-dk-2  │ standard.large       │ 0.0.0.0         │ running │
    ```

    ```diff
    machines = {
    "control-plane-1" : {
        "node_type" : "master",
        "size" : "Medium",
   +   "family" : "standard",
        "boot_disk" : {
        "image_name" : "Linux Ubuntu 20.04 LTS 64-bit",
        "root_partition_size" : 50,
        "node_local_partition_size" : 0,
        "ceph_partition_size" : 50
        }
    },
    }
    ```

1. Run the migration script

    ```console
    migration/v2.21.0-ck8sx-v2.22.0-ck8sx/migrate-exoscale.sh sc
    migration/v2.21.0-ck8sx-v2.22.0-ck8sx/migrate-exoscale.sh wc
    ```

1. The final plan should look like X

    ```console
    ...
    ```

1. Copy over the new state and delete the temp state

    ```console
    cp "$CK8S_CONFIG_PATH/sc-config/terraform-temp.tfstate" "$CK8S_CONFIG_PATH/sc-config/terraform.tfstate"
    rm "$CK8S_CONFIG_PATH/sc-config/terraform-temp.tfstate"
    rm "$CK8S_CONFIG_PATH/sc-config/terraform-temp.tfstate.backup"

    cp "$CK8S_CONFIG_PATH/wc-config/terraform-temp.tfstate" "$CK8S_CONFIG_PATH/wc-config/terraform.tfstate"
    rm "$CK8S_CONFIG_PATH/wc-config/terraform-temp.tfstate"
    rm "$CK8S_CONFIG_PATH/wc-config/terraform-temp.tfstate.backup"
    ```
