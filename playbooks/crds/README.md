# CRDs

Currently used to define the ServiceMonitors CRD early.

The CRD should be kept in sync with the one in the latest Apps release.

```bash
APPS_TAG="$(curl -s https://api.github.com/repos/elastisys/compliantkubernetes-apps/releases | jq -r '.[].tag_name' | sort --version-sort --reverse | head --lines 1)"

curl -fsSLO "https://raw.githubusercontent.com/elastisys/compliantkubernetes-apps/refs/tags/${APPS_TAG}/helmfile.d/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml"
```
