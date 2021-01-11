# Elastisys Compliant Kubernetes Kubespray

**NOTE: This project is in alpha stage and is actively developed. Therefore the API may change in backwards-incompatible ways.**

Content:

- `bin`: wrapper scripts that helps you run kubespray
- `config`: default config values
- `conformance-tests`: ck8s conformance tests for bare metal machines
- `kubespray`: git submodule of the kubespray repository

## Quick start

1. Init the kubespray config in your config path
   ```
   export CK8S_CONFIG_PATH=~/.ck8s/my-environment
   ./bin/ck8s-kubespray init <prefix> <flavor> <path to ssh key> [<SOPS fingerprint>]
   ```
   Arguments:
   * `prefix` will be used to differentiate this cluster from others in the same CK8S_CONFIG_PATH. For now you need to set this to `wc` or `sc` if you want to install compliantkubernetes apps on top afterwards, this restriction will be removed later.
   * `flavor` will determine some default values for a variety of config options. Supported options are `default`.
   * `path to ssh key` should point to a ssh key that can access all nodes that will be a part of the cluster. It will be copied into your config path and encrypted with SOPS, the original file left as it were.
   * `SOPS fingerprint` is the gpg fingerprint that will be used for SOPS encryption. You need to set this or the environment variable `CK8S_PGP_FP` the first time SOPS is used in your specified config path.
2. Edit the IP addresses and nodes in your `inventory.ini` (found in your config path) to match the VMs that should be part of the cluster.
3. Init and update the [kubespray](https://github.com/kubernetes-sigs/kubespray) gitsubmodule (currently using `release-2.13`):
   ```
   git submodule init
   git submodule update
   ```
4. Run kubespray to set up the kubernetes cluster:
   ```
   ./bin/ck8s-kubespray apply <prefix> [<options>]
   ```
   Any `options` added will be forwarded to ansible.
5. Done. You should now have a working kubernetes cluster. You should also have an encrypted kubeconfig at `<CK8S_CONFIG_PATH>/.state/kube_config_<prefix>.yaml` that you can use to access the cluster.

## Running other kubespray playbooks

With the following command you can run any ansible playbook available in kubespray:
```
./bin/ck8s-kubespray run-playbook <prefix> <playbook> [<options>]
```
Where `playbook` is the filename of the playbook that you want to run, e.g. `cluster.yml` if you want to create a cluster (making the command functionally the same as our `ck8s-kubespray apply` command) or `scale.yml` if you want to just add more nodes. Remember to check the kubespray documentation before running a playbook.
This will use the inventory, group-vars, and ssh key in your config path and therefore requires that you first run the init command. Any `options` added will be forwarded to ansible.
