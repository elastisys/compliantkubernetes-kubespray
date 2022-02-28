#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

helm repo add rook-release https://charts.rook.io/release

namespace="rook-ceph"
release_name="rook-ceph"
chart="rook-release/rook-ceph"
chart_version="v1.5.3"

# Install rook operator
kubectl create namespace "${namespace}" --dry-run -o yaml | kubectl apply -f -
kubectl label namespace "${namespace}" owner=operator --overwrite
helm upgrade --install --namespace "${namespace}" "${release_name}" "${chart}" \
  --version "${chart_version}" --values "${here}/operator-values.yaml" --wait

# Install ceph cluster
kubectl --namespace "${namespace}" apply -f "${here}/cluster.yaml"

# Create storageclass
kubectl --namespace "${namespace}" apply -f "${here}/storageclass.yaml"

kubectl --namespace "${namespace}" apply -f "${here}/toolbox-deploy.yaml"
