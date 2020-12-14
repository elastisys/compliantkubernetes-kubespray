#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Usage: $0 <kubeconfig> <ip>" >&2
  exit 1
fi

kubeconfig=$1
ip=$2

sops --set '["clusters"][0]["cluster"]["server"] "https://'"${ip}"':6443"' "${kubeconfig}"
