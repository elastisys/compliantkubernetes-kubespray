#!/usr/bin/env bash

kubectl delete -n kube-system ds calico-node --wait
kubectl delete -n kube-system ds calico-accountant --wait
kubectl delete -n kube-system deployment calico-kube-controllers --wait

mapfile -t CALICO_CRDS < <(kubectl api-resources --api-group=crd.projectcalico.org -o name)
if [[ "${#CALICO_CRDS[@]}" -gt 0 ]]; then
  kubectl delete crds "${CALICO_CRDS[@]}"
fi
