#!/usr/bin/env bash

# fn <address> <subnet>
addressInSubnet() {
  python3 -c "import ipaddress; exit(0) if ipaddress.ip_address('${1}') in ipaddress.ip_network('${2}') else exit(1)"
}

# fn <key> <addresses>
updatePeers() {
  peers="$(yq ".commons * .clusters.${cluster} | .networkPolicies.${1} | .[].cidr" "${CK8S_CONFIG_PATH}/rook/values.yaml")"

  local -a update

  for address in ${2}; do
    for peer in ${peers}; do
      if ! [[ "${peer}" =~ ^.*/32$ ]] && addressInSubnet "${address}" "${peer}"; then
        update+=("${peer}")
        continue 2
      fi
    done

    update+=("${address}/32")
  done

  old="$(yq -oj -I0 '[split(" ") | sort | .[] | {"cidr": .}]' <<<"$peers")"
  new="$(yq -oj -I0 '[split(" ") | sort | unique | .[] | {"cidr": .}]' <<<"${update[*]}")"

  if ! diff -u3 --color --label "current .commons * .clusters.${cluster} | .${1}" <(yq -P <<<"$old") --label "update .cluster.${cluster}.${1}" <(yq -P <<<"$new"); then
    echo -n "apply update? [Y/n]: "
    read -r reply
    if [[ "${reply}" =~ ^(Y|y|)$ ]]; then
      yq -i ".clusters.${cluster}.networkPolicies.${1} = ${new}" "${CK8S_CONFIG_PATH}/rook/values.yaml"
    fi
  else
    echo "- ${cluster}/networkPolicies/${1}: up to date"
  fi
}

if [[ -z "${CK8S_CONFIG_PATH:-}" ]]; then
  echo "err: missing CK8S_CONFIG_PATH" >&2
  exit
elif [[ -z "${1:-}" ]]; then
  echo "err: missing cluster name" >&2
  exit
elif [[ "$(yq ".clusters | keys | [\"${1}\"] - . | length" "${CK8S_CONFIG_PATH}/rook/values.yaml")" == "1" ]]; then
  echo "err: invalid cluster name" >&2
  exit
fi

cluster="${1}"

if kubectl -n kube-system get svc kube-dns >/dev/null 2>&1; then
  dnsAddresses="$(kubectl -n kube-system get svc kube-dns -ojsonpath='{.spec.clusterIPs[0]}')"
else
  dnsAddresses="$(kubectl -n kube-system get svc coredns -ojsonpath='{.spec.clusterIPs[0]}')"
fi

apiserverAddresses="$(
  kubectl get no -lnode-role.kubernetes.io/control-plane= -oyaml | yq '[
  .items[] | [
    .status.addresses[] | select(.type == "InternalIP") | .address
  ] + (
    .metadata.annotations | [
        ."projectcalico.org/IPv4VXLANTunnelAddr", ."projectcalico.org/IPv6VXLANTunnelAddr",
        ."projectcalico.org/IPv4IPIPTunnelAddr",
        ."projectcalico.org/IPv4WireguardInterfaceAddr", ."projectcalico.org/IPv6WireguardInterfaceAddr"
    ]) | .[]] | sort | .[]'
)"

nodeAddresses="$(
  kubectl get no -oyaml | yq '[
  .items[] | [
    .status.addresses[] | select(.type == "InternalIP") | .address
  ] + (
    .metadata.annotations |
      [
        ."projectcalico.org/IPv4VXLANTunnelAddr", ."projectcalico.org/IPv6VXLANTunnelAddr",
        ."projectcalico.org/IPv4IPIPTunnelAddr",
        ."projectcalico.org/IPv4WireguardInterfaceAddr", ."projectcalico.org/IPv6WireguardInterfaceAddr"
      ]) | .[]] | sort | .[]'
)"

echo "checking networkpolicies..."
updatePeers dnsPeers "${dnsAddresses}"
updatePeers apiserverPeers "${apiserverAddresses}"
updatePeers nodePeers "${nodeAddresses}"

echo "checking podsecuritypolicies..."

pspcrds=(
  k8spspallowedusers.constraints.gatekeeper.sh
  k8spspallowprivilegeescalationcontainer.constraints.gatekeeper.sh
  k8spspapparmor.constraints.gatekeeper.sh
  k8spspcapabilities.constraints.gatekeeper.sh
  k8spspflexvolumes.constraints.gatekeeper.sh
  k8spspforbiddensysctls.constraints.gatekeeper.sh
  k8spspfsgroup.constraints.gatekeeper.sh
  k8spsphostfilesystem.constraints.gatekeeper.sh
  k8spsphostnamespace.constraints.gatekeeper.sh
  k8spsphostnetworkingports.constraints.gatekeeper.sh
  k8spspprivilegedcontainer.constraints.gatekeeper.sh
  k8spspprocmount.constraints.gatekeeper.sh
  k8spspreadonlyrootfilesystem.constraints.gatekeeper.sh
  k8spspseccomp.constraints.gatekeeper.sh
  k8spspselinuxv2.constraints.gatekeeper.sh
  k8spspvolumetypes.constraints.gatekeeper.sh
)

if [[ "$(yq ".commons * .clusters.${cluster} | .podSecurityPolicies.enabled" "${CK8S_CONFIG_PATH}/rook/values.yaml")" != "true" ]]; then
  if kubectl get crds "${pspcrds[@]}" &>/dev/null; then
    echo -n "- enable Gatekeeper podsecuritypolicies? [Y/n]: "
    read -r reply
    if [[ "${reply}" =~ ^(Y|y|)$ ]]; then
      yq -i ".clusters.${cluster}.podSecurityPolicies.enabled = true" "${CK8S_CONFIG_PATH}/rook/values.yaml"
    fi
  else
    echo "- warning: Gatekeeper constraints not available"
  fi
else
  echo "- podsecuritypolicies enabled"
fi

echo "checking service monitors..."
if [[ "$(yq ".commons * .clusters.${cluster} | .monitoring.installServiceMonitors" "${CK8S_CONFIG_PATH}/rook/values.yaml")" != "true" ]]; then
  if kubectl get crd prometheuses.monitoring.coreos.com &>/dev/null; then
    if [[ -n "$(kubectl get po -A -l app.kubernetes.io/name=prometheus 2>/dev/null)" ]]; then
      echo -n "- install Prometheus service monitors? [Y/n]: "
      read -r reply
      if [[ "${reply}" =~ ^(Y|y|)$ ]]; then
        yq -i ".clusters.${cluster}.monitoring.installServiceMonitors = true" "${CK8S_CONFIG_PATH}/rook/values.yaml"
      fi
    else
      echo "- note: Prometheus not available"
    fi
  else
    echo "- note: Prometheus operator not available"
  fi
else
  echo "- service monitors installed"
fi

echo "checking dashboards..."
if [[ "$(yq ".commons * .clusters.${cluster} | .monitoring.installGrafanaDashboards" "${CK8S_CONFIG_PATH}/rook/values.yaml")" != "true" ]]; then
  if [[ -n "$(kubectl get po -A -l app.kubernetes.io/name=grafana 2>/dev/null)" ]]; then
    echo -n "- install Grafana dashboards? [Y/n]: "
    read -r reply
    if [[ "${reply}" =~ ^(Y|y|)$ ]]; then
      yq -i ".clusters.${cluster}.monitoring.installGrafanaDashboards = true" "${CK8S_CONFIG_PATH}/rook/values.yaml"
    fi
  else
    echo "- note: Grafana not available"
  fi
else
  echo "- dashboards installed"
fi

echo "checking rules..."
if [[ "$(yq ".commons * .clusters.${cluster} | .monitoring.installPrometheusRules" "${CK8S_CONFIG_PATH}/rook/values.yaml")" != "true" ]]; then
  if kubectl get crd prometheusrules.monitoring.coreos.com &>/dev/null; then
    if [[ -n "$(kubectl get po -A -l app.kubernetes.io/name=thanos 2>/dev/null)" ]]; then
      echo -n "- install Prometheus rules? [Y/n]: "
      read -r reply
      if [[ "${reply}" =~ ^(Y|y|)$ ]]; then
        yq -i ".clusters.${cluster}.monitoring.installPrometheusRules = true" "${CK8S_CONFIG_PATH}/rook/values.yaml"
      fi
    else
      echo "- note: Thanos not available"
    fi
  else
    echo "- note: Prometheus operator not available"
  fi
else
  echo "- rules installed"
fi
