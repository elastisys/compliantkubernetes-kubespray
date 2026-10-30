This `Dockerfile` takes one source image and replaces the trust bundle with one from trust-manager. The `fix.sh` script transforms the name of the image, replacing `registry.k8s.io` with `ghcr.io/elastisys` and pushes the fixed images there.

This was used to fix the following images:

- `registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.5.0`
- `registry.k8s.io/sig-storage/csi-attacher:v4.4.2`
- `registry.k8s.io/sig-storage/csi-provisioner:v3.6.2`
- `registry.k8s.io/sig-storage/csi-resizer:v1.9.2`
- `registry.k8s.io/sig-storage/csi-snapshotter:v6.3.2`
- `registry.k8s.io/sig-storage/livenessprobe:v2.11.0`
- `registry.k8s.io/sig-storage/snapshot-controller:v7.0.2`
- `registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.4.0`
- `registry.k8s.io/sig-storage/csi-attacher:v3.4.0`
- `registry.k8s.io/sig-storage/csi-provisioner:v3.1.0`
- `registry.k8s.io/sig-storage/csi-resizer:v1.4.0`

```console
$ for image in registry.k8s.io/sig-storage/csi-attacher:v4.4.2 ...; do
    ./fix.sh "$image";
  done
```
