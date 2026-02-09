#!/usr/bin/env bash

kubectl delete -n kube-system daemonset calico-node --wait --ignore-not-found
kubectl delete -n kube-system daemonset calico-accountant --wait --ignore-not-found
kubectl delete -n kube-system deployment calico-kube-controllers --wait --ignore-not-found
kubectl delete -n kube-system deployment calico-typha --wait --ignore-not-found

mapfile -t CALICO_CRDS < <(kubectl api-resources --api-group=crd.projectcalico.org -o name)
if [[ "${#CALICO_CRDS[@]}" -gt 0 ]]; then
  kubectl delete crds "${CALICO_CRDS[@]}"
fi
