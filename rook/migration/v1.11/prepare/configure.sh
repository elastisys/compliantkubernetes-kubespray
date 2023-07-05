#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"

if [[ ! -f "${CK8S_CONFIG_PATH}/rook/values.yaml" ]]; then
  echo "copying new values template"
  cp "${HERE}/../../../template/values.yaml" "${CK8S_CONFIG_PATH}/rook/values.yaml"
fi

if [[ -f "${CK8S_CONFIG_PATH}/rook/operator-values.yaml" ]]; then
  echo "reading ceph operator values from file"

  echo "- copying operator toleration"
  echo "  - these are reused for csi provisioner and plugin"
  yq4 -i ".commons.operator.tolerations = $(yq4 -oj '.tolerations' "${CK8S_CONFIG_PATH}/rook/operator-values.yaml")" "${CK8S_CONFIG_PATH}/rook/values.yaml"
fi

if [[ -f "${CK8S_CONFIG_PATH}/rook/cluster.yaml" ]]; then
  echo "reading ceph cluster values from file"

  echo "- copying storage values"
  yq4 -i ".commons.cluster.storage = $(yq4 -oj ".spec.storage" "${CK8S_CONFIG_PATH}/rook/cluster.yaml")" "${CK8S_CONFIG_PATH}/rook/values.yaml"

  for key in $(yq4 '.spec.placement | keys | .[]' "${CK8S_CONFIG_PATH}/rook/cluster.yaml"); do
    echo "- copying placement values for ${key}"
    yq4 -i ".commons.cluster.${key} = $(yq4 -oj ".spec.placement.${key}" "${CK8S_CONFIG_PATH}/rook/cluster.yaml")" "${CK8S_CONFIG_PATH}/rook/values.yaml"
  done
fi

if [[ -f "${CK8S_CONFIG_PATH}/rook/storageclass.yaml" ]]; then
  echo "reading block pool and storage class values from file"

  block_pool="$(yq4 'select(.kind == "CephBlockPool") | .metadata.name' "${CK8S_CONFIG_PATH}/rook/storageclass.yaml")"
  if [[ "${block_pool}" != "null" ]]; then
    echo "- copying block pool values for ${block_pool}"
    yq4 -i ".commons.cluster.cephBlockPool.name = \"${block_pool}\"" "${CK8S_CONFIG_PATH}/rook/values.yaml"
  else
    echo "--- warning unable to find block pool values ---"
  fi

  storage_class="$(yq4 'select(.kind == "StorageClass") | .metadata.name' "${CK8S_CONFIG_PATH}/rook/storageclass.yaml")"
  if [[ "${storage_class}" != "null" ]]; then
    echo "- copying storage class values for ${storage_class}"
    yq4 -i ".commons.cluster.storageClass.name = \"${storage_class}\"" "${CK8S_CONFIG_PATH}/rook/values.yaml"
  else
    echo "--- warning unable to find storage class values ---"
  fi
fi
