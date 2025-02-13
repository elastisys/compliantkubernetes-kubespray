#!/bin/bash

set -eu -o pipefail

if [[ -z "$CK8S_APPS_PIPELINE" ]]; then
  exit 1
fi

if [[ "$CLUSTER" = "sc" ]]; then
  helmfile -e service apply &>/dev/null
elif [[ "$CLUSTER" = "wc" ]]; then
  helmfile -e workload apply &>/dev/null
fi
