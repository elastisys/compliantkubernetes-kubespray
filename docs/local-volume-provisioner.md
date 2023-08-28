# Setting up local volume provisioner

## Steps

To setup local volume provisioner on a node, add the following snippet to your ck8s-k8s-openstack.yaml. See the [docs](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/kubernetes-apps/local_volume_provisioner.md) for more info.

```yaml
local_volume_provisioner_enabled: false #set this to true
local_volume_provisioner_storage_classes: #For each key in local_volume_provisioner_storage_classes a "storage class" with the same name is created.
  local-storage:
    host_dir: /mnt/disks
    mount_dir: /mnt/disks
```

> [!NOTE]
> You need to make the partitions on the node beforehand.

To make the partition on a node add the the cloudinit script to your terraform values file and create a new node. This has been tested on openstack clouds.

```yaml
k8s_nodes = {
  "worker-x" = {
    "az"          = "nova"
    "flavor"      = "xxxx" #2C-8GB b2.c2r8
    "floating_ip" = "false"
    "root_volume_size_in_gb" = "100" #add this for safespring and not for elastx
    "cloudinit"   = {
      "extra_partitions" = [{
        "volume_path"     = "/dev/sda" #The root volume may differ between clouds
        "partition_path"  = "/dev/sda2"
        "partition_start" = "50GB"
        "partition_end"   = "-1"
        "mount_path"      = "/mnt/disks/node-local-storage"
      }]
    }
  }
}
```

Once you have the partitions made and the kubespray values ready, apply the manifest using

```bash
./bin/ck8s-kubespray apply sc -b --tags=local-volume-provisioner
./bin/ck8s-kubespray apply wc -b --tags=local-volume-provisioner
```
