# Elastisys Compliant Kubernetes Kubespray

**NOTE: This project is in alpha stage and is actively developed. Therefore the API may change in backwards-incompatible ways.**

Content:

- `bin`: wrapper scripts that helps you run kubespray
- `config`: default config values
- `conformance-tests`: ck8s conformance tests for bare metal machines
- `kubespray`: git submodule of the kubespray repository

## Quick start

1. Init the kubespray config in your config path

    ```bash
    export CK8S_CONFIG_PATH=~/.ck8s/my-environment
    ./bin/ck8s-kubespray init <prefix> <flavor> [<SOPS fingerprint>]
    ```

    Arguments:
    * `prefix` will be used to differentiate this cluster from others in the same CK8S_CONFIG_PATH.
      For now you need to set this to `wc` or `sc` if you want to install compliantkubernetes apps on top afterwards, this restriction will be removed later.
    * `flavor` will determine some default values for a variety of config options.
      Supported options are `default`, `gcp`, `aws`, `vsphere`, and `openstack`.
    * `SOPS fingerprint` is the gpg fingerprint that will be used for SOPS encryption.
      You need to set this or the environment variable `CK8S_PGP_FP` the first time SOPS is used in your specified config path.

1. Edit the `inventory.ini` (found in your config path) to match the VMs (IP addresses and other settings that might be needed for your setup) that should be part of the cluster.
   Or if you have one created by a terraform script in `kubespray/contrib/terraform` you should use that one.

1. Init and update the [kubespray](https://github.com/kubernetes-sigs/kubespray) gitsubmodule:

    ```bash
    git submodule init
    git submodule update
    ```

1. Run kubespray to set up the kubernetes cluster:

   ```bash
   ./bin/ck8s-kubespray apply <prefix> [<options>]
   ```

   Any `options` added will be forwarded to ansible.

1. Done.
   You should now have a working kubernetes cluster.
   You should also have an encrypted kubeconfig at `<CK8S_CONFIG_PATH>/.state/kube_config_<prefix>.yaml` that you can use to access the cluster.

## Changing authorized SSH keys for a cluster

Authorized SSH keys can be changed for a cluster using:

```bash
./bin/ck8s-kubespray apply-ssh <prefix> [<options>]
```

It will set the public SSH key(s) found in`<CK8S_CONFIG_PATH>/<prefix>-config/group_vars/all/ck8s-ssh-keys.yaml` as authorized keys in your cluster (just add the keys you want to be authorized as elements in `ck8s_ssh_pub_keys_list`).
Note that the authorized SSH keys for the cluster will be set to these keys _exclusively_, removing any keys that may already be authorized, so make sure the list includes **every SSH key** that should be authorized.

When running this command, the SSH keys are applied to each node in the cluster sequentially, in reverse inventory order (first the workers and then the masters).
A connection test is performed after each node which has to succeed in order for the playbook to continue.
If the connection test fails, you may have lost your SSH access to the node; to recover from this, you can set up an SSH connection before running the command and keep it active so that you can change the authorized keys manually.

## Rebooting nodes

You can reboot all nodes that wants to restart (usually to finish installing new packages) by running:

```bash
./bin/ck8s-kubespray reboot-nodes <prefix> [--extra-vars manual_prompt=true] [<options>]
```

If you set `--extra-vars manual_prompt=true` then you get a manual prompt before each reboot so you can stop the playbook if you want.

## Running other kubespray playbooks

With the following command you can run any ansible playbook available in kubespray:

```bash
./bin/ck8s-kubespray run-playbook <prefix> <playbook> [<options>]
```

Where `playbook` is the filename of the playbook that you want to run, e.g. `cluster.yml` if you want to create a cluster (making the command functionally the same as our `ck8s-kubespray apply` command) or `scale.yml` if you want to just add more nodes. Remember to check the kubespray documentation before running a playbook.
This will use the inventory, group-vars, and ssh key in your config path and therefore requires that you first run the init command. Any `options` added will be forwarded to ansible.
