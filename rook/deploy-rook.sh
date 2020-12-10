#!/usr/bin/env bash

set -euo pipefail

helm repo add rook-release https://charts.rook.io/release

namespace="rook-ceph"
release_name="rook-ceph"
chart="rook-release/rook-ceph"
chart_version="v1.5.3"

# Install rook operator
kubectl create namespace $namespace --dry-run -o yaml | kubectl apply -f -
helm upgrade --install --namespace $namespace $release_name $chart \
  --version $chart_version --values operator-values.yaml --wait

# Install ceph cluster
kubectl --namespace $namespace apply -f cluster.yaml

# Create storageclass
kubectl --namespace $namespace apply -f storageclass.yaml
