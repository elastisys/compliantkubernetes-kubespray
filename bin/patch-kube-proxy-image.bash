#!/bin/bash

# It's currently not possible to patch the kube-proxy image using Kubeadm.
# Instead run this after setting up or upgrading a cluster.
# See:
# https://github.com/kubernetes/kubeadm/issues/2680
# https://github.com/kubernetes/kubeadm/issues/3288

set -eu -o pipefail
shopt -s globstar nullglob dotglob

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

kube_proxy_image="$(yq "${config_path}/ck8s-kube-proxy-image")"
ops_kubectl "${prefix}" -n kube-system set image daemonset/kube-proxy kube-proxy="${kube_proxy_image}"
