# Upgrade v2.20.0-ck8sx to v2.21.0-ck8sx

1. Checkout the new release: `git checkout v2.21.0-ck8sx`

1. Switch to the correct remote: `git submodule sync`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. Add the following snippet at the end of both `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml`

    This enables NTP service and with multiple NTP servers, specificity in sweden.
    You can visit [www.ntppool.org](https://www.ntppool.org/zone/@) to find other ntp pools if you are in other parts of the world.

    ```yaml
    ntp_enabled: true
    ntp_manage_config: true
    ntp_servers:
    - "gbg1.ntp.netnod.se iburst"
    - "gbg2.ntp.netnod.se iburst"
    - "lul1.ntp.netnod.se iburst"
    - "lul2.ntp.netnod.se iburst"
    - "mmo1.ntp.netnod.se iburst"
    - "mmo2.ntp.netnod.se iburst"
    - "sth1.ntp.netnod.se iburst"
    - "sth2.ntp.netnod.se iburst"
    - "sth3.ntp.netnod.se iburst"
    - "sth4.ntp.netnod.se iburst"
    - "svl1.ntp.netnod.se iburst"
    - "svl2.ntp.netnod.se iburst"
    ntp_timezone: "Etc/UTC"
    ```

## Disruptive steps

These steps will cause disruptions in the environment.

1. Upgrade the cluster to a new kubernetes version:

    ```bash
    ./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b
    ./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b
    ```
