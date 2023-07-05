#!/usr/bin/env bash

if [[ -z "${1:-}" ]]; then
  echo "missing cluster argument"
  exit 1
fi

block_pool="$(yq4 ".commons * .clusters.${1} | .cluster.cephBlockPool.name // \"replicapool\"" "${CK8S_CONFIG_PATH}/rook/values.yaml")"
storage_class="$(yq4 ".commons * .clusters.${1} | .cluster.storageClass.name // \"rook-ceph-block\"" "${CK8S_CONFIG_PATH}/rook/values.yaml")"

kubectl annotate namespace rook-ceph meta.helm.sh/release-namespace=kube-system meta.helm.sh/release-name=rook-ceph-namespace --overwrite
kubectl label namespace rook-ceph app.kubernetes.io/managed-by=Helm --overwrite

kubectl -n rook-ceph annotate configmap rook-config-override meta.helm.sh/release-namespace=rook-ceph meta.helm.sh/release-name=rook-ceph-cluster --overwrite
kubectl -n rook-ceph label configmap rook-config-override app.kubernetes.io/managed-by=Helm --overwrite

kubectl -n rook-ceph annotate cephcluster rook-ceph meta.helm.sh/release-namespace=rook-ceph meta.helm.sh/release-name=rook-ceph-cluster --overwrite
kubectl -n rook-ceph label cephcluster rook-ceph app.kubernetes.io/managed-by=Helm --overwrite


kubectl -n rook-ceph annotate cephblockpool "${block_pool}" meta.helm.sh/release-namespace=rook-ceph meta.helm.sh/release-name=rook-ceph-cluster --overwrite
kubectl -n rook-ceph label cephblockpool "${block_pool}" app.kubernetes.io/managed-by=Helm --overwrite

kubectl -n rook-ceph annotate storageclass "${storage_class}" meta.helm.sh/release-namespace=rook-ceph meta.helm.sh/release-name=rook-ceph-cluster --overwrite
kubectl -n rook-ceph label storageclass "${storage_class}" app.kubernetes.io/managed-by=Helm --overwrite
