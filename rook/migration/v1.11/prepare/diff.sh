#!/usr/bin/env bash

if [[ -z "${1:-}" ]]; then
  echo "missing cluster argument"
  exit 1
fi

block_pool="$(yq4 ".commons * .clusters.${1} | .cluster.cephBlockPool.name // \"replicapool\"" "${CK8S_CONFIG_PATH}/rook/values.yaml")"
storage_class="$(yq4 ".commons * .clusters.${1} | .cluster.storageClass.name // \"rook-ceph-block\"" "${CK8S_CONFIG_PATH}/rook/values.yaml")"

echo "diffing cluster..."
diff -u3 --color \
  --label current <(kubectl -n rook-ceph get cephclusters.ceph.rook.io rook-ceph -oyaml | yq4 'sort_keys(...) | del(.metadata.annotations,.metadata.creationTimestamp,.metadata.finalizers,.metadata.generation,.metadata.namespace,.metadata.resourceVersion,.metadata.uid,.status)') \
  --label pending <(helmfile -e "${1}" -l app=cluster template | yq4 'select(.kind == "CephCluster") | sort_keys(...)')
echo "---"

echo "diffing block pool..."
diff -u3 --color \
  --label current <(kubectl -n rook-ceph get cephblockpools.ceph.rook.io "${block_pool}" -oyaml | yq4 'sort_keys(...) | del(.metadata.annotations,.metadata.creationTimestamp,.metadata.finalizers,.metadata.generation,.metadata.namespace,.metadata.resourceVersion,.metadata.uid,.status)') \
  --label pending <(helmfile -e service -l app=cluster template | yq4 'select(.kind == "CephBlockPool") | sort_keys(...)')
echo "---"

echo "diffing storage class..."
diff -u3 --color \
  --label current <(kubectl -n rook-ceph get storageclass "${storage_class}" -oyaml | yq4 'sort_keys(...) | del(.metadata.annotations,.metadata.creationTimestamp,.metadata.finalizers,.metadata.generation,.metadata.namespace,.metadata.resourceVersion,.metadata.uid,.status)') \
  --label pending <(helmfile -e service -l app=cluster template | yq4 'select(.kind == "StorageClass") | sort_keys(...)')
echo "---"
