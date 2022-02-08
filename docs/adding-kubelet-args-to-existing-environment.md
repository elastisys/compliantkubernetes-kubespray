# Adding kubelet variables to existing environment

Start with switching to the correct compliantkubernetes-kubespray release.
Add the kubelet arguments in `sc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml` and `wc-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml`.

Possible arguments to give kubelet can be found here: [kubelet arguments](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration).

The following is a example of changing when to garbage collect unused images

```yaml
...
kubelet_config_extra_args:
  imageGCHighThresholdPercent: 75
  imageGCLowThresholdPercent: 70
```

To apply the change run the following ck8s-kubespray command:

```bash
./bin/ck8s-kubespray apply sc --tags=node
./bin/ck8s-kubespray apply wc --tags=node
```
