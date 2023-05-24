#!/usr/bin/env bash


apply() {
  condition="$(kubectl -n kube-system get configmap kubeadm-config -o yaml | yq4 '.data.ClusterConfiguration | @yamld | .apiServer.extraArgs.enable-admission-plugins | split(",") | .[] | select(. == "PodSecurityPolicy")')"
  if [[ "${condition}" != "PodSecurityPolicy" ]]; then
    echo "- skipping - Kubernetes PodSecurityPolicy admission not enabled"
    return
  fi

  echo "  - applying temporary bypass of vanilla Kubernetes PodSecurityPolicies"

  if [[ -z "$(kubectl -n rook-ceph get rolebinding bypass-kubernetes-psp --ignore-not-found=true)" ]]; then
    echo "  - applying rook-ceph bypass psp - "
    kubectl -n rook-ceph create rolebinding bypass-kubernetes-psp --clusterrole psp:privileged --group "system:serviceaccounts:rook-ceph"
  else
    echo "  - skipping rook-ceph - already exists"
  fi
}

delete() {
  echo "- deleting temporary bypass of vanilla Kubernetes PodSecurityPolicies"

  if [[ "$(kubectl -n rook-ceph get rolebinding bypass-kubernetes-psp --ignore-not-found=true)" ]]; then
    echo "  - deleting rook-ceph bypass psp - "
    kubectl -n rook-ceph delete rolebinding bypass-kubernetes-psp
  else
    echo "  - bypass-kubernets-psp was deleted"
  fi
}

run() {
  case "${1:-}" in
  execute)
    apply
    ;;
  clean)
    delete
    ;;
  *)
    echo "usage: \"${0}\" <execute|clean>"
    ;;
  esac
}

run "${@}"
