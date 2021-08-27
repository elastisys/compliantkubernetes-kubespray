#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

namespace="rook-ceph"
release_name="rook-ceph"

# Remove toolbox
kubectl --namespace "${namespace}" delete -f "${here}/toolbox-deploy.yaml"

# Remove ceph cluster
kubectl -n "${namespace}" patch cephclusters.ceph.rook.io "${namespace}" -p '{"metadata":{"finalizers": []}}' --type=merge
kubectl --namespace "${namespace}" delete -f "${here}/cluster.yaml"

# Remove storageclass
kubectl --namespace "${namespace}" delete -f "${here}/storageclass.yaml"

# Remove rook operator and namespace
helm uninstall --namespace "${namespace}" "${release_name}"
kubectl delete namespace "${namespace}"
