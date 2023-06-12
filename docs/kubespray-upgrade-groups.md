# Kubespray upgrade groups

Currently, the default upgrade method of kubespray, is to take all nodes in sequence to avoid any downtime situations, but this takes too much time.
So, the goal is that we want to constraint the time an upgrade takes as far as we could, so it can be predictable for both operators & users.

The managed upgrade scripts should allow us to :

- Generate a static inventory with different groups of nodes based on their type ( elastisys, worker, postgres, control plane ... etc)

- Upgrade the control planes first

- Upgrade the groups in parallel by taking only one node per group, in sequence

- Pick the order in which nodes to upgrade first to avoid downtime for databases. In case of primary-secondary replication, we should start with node that host the secondaries first

To generate the static inventory with the groups, make sure to have the following variables under your `$CK8S_CONFIG_PATH/(sc|wc)-config/group_vars/all/ck8s-kubespray-general.yaml`:

```yaml
control_plane_label: node-role.kubernetes.io/control-plane
group_label_primary: elastisys.io/node-type
group_label_secondary: elastisys.io/ams-cluster-name
```

Once done, you can generate the groups inventory by running:

```bash
./bin/ck8s-kubespray generate-groups-inventory sc|wc
```

The command above should generate a new inventory file called `groups-inventoy` under (sc|wc)-config folder.

To list the groups:

```bash
./bin/ck8s-kubespray upgrade-groups sc|wc list-groups
```

To run the upgrade of the groups:

```bash
./bin/ck8s-kubespray upgrade-groups sc|wc apply
```

The command above will start upgrading the control-plane nodes one by one, and move to the groups and upgrade them in parallel.
