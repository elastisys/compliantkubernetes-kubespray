# Preserving source IP on CityCloud (proxy protocol)

> [!NOTE]
> This workaround is not needed after [this PR](https://github.com/kubernetes-sigs/kubespray/pull/8629) is part of the release (probably at v1.23.0).

To use proxy protocol on the loadbalancers on citycloud you'll need to update the cloud controller manager to version `v1.22.0`.
This can be achieved by setting the following `k8s_cluster` group variables:

```yaml
external_openstack_cloud_controller_image_tag: "v1.22.0"
external_openstack_enable_ingress_hostname: true
```

Apply the changes:

```bash
bin/ck8s-kubespray apply sc --tags=external-openstack
```

You also need to apply an updated clusterrole:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/kubespray/be03d8ac2fca812c980c6515c8a6bb0d4b1ac243/roles/kubernetes-apps/external_cloud_controller/openstack/templates/external-openstack-cloud-controller-manager-roles.yml.j2
```

After this if you already have a loadbalancer you can add the annotation `loadbalancer.openstack.org/proxy-protocol: true` to the loadbalancer service and make sure that the backing service supports the proxy protocol.
The cloud controller will automatically change the pool of the loadbalancer to use the proxy protocol so there might be a couple of seconds downtime while the change is made but otherwise it shouldn't change anything else.

For [Compliant Kubernetes](https://github.com/elastisys/compliantkubernetes-apps) this specifically means making the following change:

```diff
ingressNginx:
  controller:
    config:
+     useProxyProtocol: true
    service:
      annotation:
+       loadbalancer.openstack.org/proxy-protocol: true
```

And then run:

```bash
bin/ck8s ops helmfile {sc|wc} -l app=ingress-nginx apply
```
