#!/usr/bin/env bash

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  tfvars_file="${CK8S_CONFIG_PATH}/sc-config/cluster.tfvars"
  if ! grep -P "^loadbalancer_legacy_network" "${tfvars_file}" >/dev/null; then
    echo "loadbalancer_legacy_network = true" >> "${tfvars_file}"
  fi
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  tfvars_file="${CK8S_CONFIG_PATH}/wc-config/cluster.tfvars"
  if ! grep -P "^loadbalancer_legacy_network" "${tfvars_file}" >/dev/null; then
    echo "loadbalancer_legacy_network = true" >> "${tfvars_file}"
  fi
fi
