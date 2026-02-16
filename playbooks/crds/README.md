# CRDs

Currently used to define the ServiceMonitors CRD early.

The CRD should be kept in sync with the one in the latest Apps release.

Make sure `CK8S_GITHUB_TOKEN` is set in the environment.

```bash
APPS_TAG="$(curl -sH "Authorization: token ${CK8S_GITHUB_TOKEN}" https://api.github.com/repos/elastisys/welkin-apps/releases | jq -r '.[].tag_name' | sort --version-sort --reverse | head --lines 1)"

curl -fsSLO -H "Authorization: token ${CK8S_GITHUB_TOKEN}" "https://raw.githubusercontent.com/elastisys/welkin-apps/refs/tags/${APPS_TAG}/helmfile.d/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml"
```
