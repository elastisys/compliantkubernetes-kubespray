#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

if [[ -z "${CK8S_CONFIG_PATH:-}" ]]; then
  echo "ASSESSMENT_ERROR: Missing CK8S_CONFIG_PATH" >&2 || true
  exit 2
fi

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=migration/calico-to-cilium/common.sh
if ! source "${HERE}/common.sh"; then
  echo "ASSESSMENT_ERROR: unable to load migration helpers" >&2 || true
  exit 2
fi

assessment_error() {
  log_error "ASSESSMENT_ERROR: ${*}" || true
  exit 2
}

require_value() {
  [[ -n "${2}" ]] || assessment_error "Missing ${1}"
}

cluster_kubectl() {
  kubectl --kubeconfig "${CK8S_CONFIG_PATH}/.state/kube_config_${TARGET_CLUSTER}.yaml" --request-timeout=30s "$@"
}

discover_cloud_provider() {
  if ! cloud_provider_json="$(yq -o=json -e '.global.ck8sCloudProvider' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml")"; then
    assessment_error "unable to read the configured cloud provider"
  fi
  case "${cloud_provider_json}" in
  '"none"' | '"openstack"' | '"upcloud"') ;;
  *) assessment_error "unsupported configured cloud provider" ;;
  esac
}
discover_network_inputs() {

  # These values describe the current cluster and can be read safely before migration.
  dns_ip="${NETWORK_POLICY_DNS_IP:-}"
  current_pod_cidr="${NETWORK_POLICY_CURRENT_POD_CIDR:-}"
  service_cidr="${NETWORK_POLICY_SERVICE_CIDR:-}"

  if [[ -z "${dns_ip}" ]]; then
    if ! dns_ip="$(cluster_kubectl -n kube-system get service kube-dns -o jsonpath='{.spec.clusterIP}')"; then
      assessment_error "unable to read the kube-dns Service IP"
    fi
  fi

  if [[ -z "${current_pod_cidr}" || -z "${service_cidr}" ]]; then
    if ! cluster_configuration="$(cluster_kubectl -n kube-system get configmap kubeadm-config -o jsonpath='{.data.ClusterConfiguration}')"; then
      assessment_error "unable to read kubeadm network configuration"
    fi
    if [[ -z "${current_pod_cidr}" ]]; then
      current_pod_cidr="$(yq -r '.networking.podSubnet // ""' <<<"${cluster_configuration}")" || assessment_error "unable to read the current Pod CIDR"
    fi
    if [[ -z "${service_cidr}" ]]; then
      service_cidr="$(yq -r '.networking.serviceSubnet // ""' <<<"${cluster_configuration}")" || assessment_error "unable to read the Service CIDR"
    fi
  fi
}

configure_inputs() {
  : "${TARGET_CLUSTER?Missing required variable}"
  discover_cloud_provider
  discover_network_inputs
  require_value NETWORK_POLICY_DNS_IP "${dns_ip}"
  require_value NETWORK_POLICY_CURRENT_POD_CIDR "${current_pod_cidr}"
  require_value NETWORK_POLICY_SERVICE_CIDR "${service_cidr}"

  readonly target_pod_cidr="10.235.64.0/18"
  # Keep jq data separate from jq programs: every value is passed as data.
  jq_args=(
    --arg dns_ip "${dns_ip}"
    --arg current_pod_cidr "${current_pod_cidr}"
    --arg target_pod_cidr "${target_pod_cidr}"
    --arg service_cidr "${service_cidr}"
  )
  readonly -a jq_args
}

validate_inputs() {
  # Exact CIDR checks below require canonical-looking IPv4 and CIDR strings.
  if ! jq -en -e "${jq_args[@]}" '
    def ipv4:
      if test("\\A(0|[1-9][0-9]{0,2})(\\.(0|[1-9][0-9]{0,2})){3}\\z") then
        split(".") | all(.[]; tonumber <= 255)
      else
        false
      end;

    def cidr:
      split("/") as $parts |
      if ($parts | length) == 2
        and ($parts[1] | test("\\A(0|[1-9][0-9]?)\\z"))
        and (($parts[1] | tonumber) <= 32)
        and ($parts[0] | ipv4)
      then
        ($parts[0] | split(".") | map(tonumber) |
          ((.[0] * 16777216) + (.[1] * 65536) + (.[2] * 256) + .[3])) as $address |
        ($parts[1] | tonumber) as $prefix |
        (pow(2; 32 - $prefix)) as $host_range |
        ($address % $host_range) == 0
      else
        false
      end;

    ($dns_ip | ipv4)
    and ($current_pod_cidr | cidr)
    and ($target_pod_cidr | cidr)
    and ($service_cidr | cidr)
  ' >/dev/null; then
    assessment_error "NetworkPolicy IP and CIDR inputs must be valid"
  fi
}

create_workspace() {
  if ! temp_dir="$(mktemp -d)"; then
    assessment_error "unable to create temporary assessment directory"
  fi
  policy_file="${temp_dir}/policies.json"
  policy_lists_file="${temp_dir}/policy-lists.jsonl"
  rules_file="${temp_dir}/rules.jsonl"
  findings_file="${temp_dir}/findings.jsonl"
  trap 'rm -rf -- "${temp_dir}"' EXIT
}

fetch_policies() {
  local application_namespaces namespace_names namespace

  if ! application_namespaces="$(cluster_kubectl get namespace --selector 'elastisys.io/owner=application-developer' -o json | jq -ce '
    if type != "object" or (.items | type) != "array" then
      error("Namespaces must be a JSON object with an items list")
    else
      [
        .items[] |
        if (.metadata | type) != "object" or (.metadata.name | type) != "string" then
          error("Namespace requires metadata.name")
        else
          .metadata.name
        end
      ]
    end
  ')"; then
    assessment_error "unable to read Application Developer namespaces"
  fi
  if ! : >"${policy_lists_file}"; then
    assessment_error "unable to prepare NetworkPolicy data"
  fi
  if [[ "${application_namespaces}" == "[]" ]]; then
    if ! printf '%s\n' '{ "items": [] }' >"${policy_file}"; then
      assessment_error "unable to prepare NetworkPolicy data"
    fi
    return
  fi
  if ! namespace_names="$(jq -r '.[]' <<<"${application_namespaces}")"; then
    assessment_error "unable to enumerate Application Developer namespaces"
  fi
  while IFS= read -r namespace; do
    if ! cluster_kubectl -n "${namespace}" get networkpolicy -o json | jq -ce --arg namespace "${namespace}" '
      if type != "object" or (.items | type) != "array" then
        error("NetworkPolicies must be a JSON object with an items list")
      else
        {
          items: [
            .items[] |
            if (.metadata | type) != "object"
              or (.metadata.name | type) != "string"
              or (.metadata.namespace | type) != "string"
              or .metadata.namespace != $namespace
            then
              error("NetworkPolicy requires matching metadata.name and metadata.namespace")
            else
              .
            end
          ]
        }
      end
    ' >>"${policy_lists_file}"; then
      assessment_error "unable to read Application Developer NetworkPolicies"
    fi
  done <<<"${namespace_names}"
  if ! jq -s '{items: [.[].items[]]}' "${policy_lists_file}" >"${policy_file}"; then
    assessment_error "unable to prepare NetworkPolicy data"
  fi
}

normalize_rules() {
  # One JSON line per active rule keeps each finding query focused and independent.
  if ! jq -c '
    def valid_selector:
      if type != "object" then
        false
      elif has("matchLabels") then
        .matchLabels |
        type == "object" and all(.[]; type == "string")
      else
        true
      end;

    def valid_peer:
      if type != "object" then
        false
      elif has("podSelector") and (.podSelector | valid_selector | not) then
        false
      elif has("namespaceSelector") and (.namespaceSelector | valid_selector | not) then
        false
      else
        true
      end;

    def policy_directions:
      if has("policyTypes") then
        .policyTypes |
        if type != "array" or length == 0 or any(.[]; . != "Ingress" and . != "Egress") then
          error("policyTypes must contain Ingress and/or Egress")
        else
          .[] | ascii_downcase
        end
      else
        "ingress", (if has("egress") then "egress" else empty end)
      end;

    .items[] |
    if type != "object"
      or (.metadata | type) != "object"
      or (.metadata.name | type) != "string"
      or (.spec | type) != "object"
    then
      error("NetworkPolicy requires metadata.name and spec")
    else
      .
    end |
    . as $policy |
    ($policy.spec | policy_directions) as $direction |
    (if $policy.spec | has($direction) then
      $policy.spec[$direction]
    else
      []
    end) as $rules |
    if ($rules | type) != "array" then
      error("NetworkPolicy rules must be a list")
    else
      $rules[]
    end |
    if type != "object" then
      error("NetworkPolicy rule must be an object")
    else
      .
    end |
    . as $rule |
    (if $direction == "egress" then "to" else "from" end) as $peer_key |
    (if $rule | has($peer_key) then $rule[$peer_key] else [] end) as $peers |
    if ($peers | type) != "array" then
      error("NetworkPolicy peers must be a list")
    elif ($peers | any(.[]; valid_peer | not)) then
      error("NetworkPolicy peers must contain valid selectors and IPBlocks")
    else
      {
        namespace: ($policy.metadata.namespace // "default"),
        policy: $policy.metadata.name,
        direction: $direction,
        rule: $rule,
        peers: $peers
      }
    end
  ' "${policy_file}" >"${rules_file}"; then
    assessment_error "unable to read NetworkPolicy rules"
  fi
}

append_findings() {
  # The filter argument comes only from fixed function-local jq literals below.
  if ! jq -c "${jq_args[@]}" "$1" "${rules_file}" >>"${findings_file}"; then
    assessment_error "unable to assess NetworkPolicies"
  fi
}

check_world_cidrs() {
  append_findings '
    select(any(.peers[]; .ipBlock.cidr? == "0.0.0.0/0")) |
    {
      rule_id: "WORLD_CIDR",
      namespace, policy, direction, rule,
      message: "Review world CIDR intent: external-world access is valid; Pod targets need selectors"
    }
  '
}

check_internal_cidrs() {
  # shellcheck disable=SC2016 # Variables belong to jq, not the shell.
  append_findings '
    select(any(.peers[]; has("podSelector") or has("namespaceSelector")) | not) |
    select(any(.peers[];
      .ipBlock.cidr? == $current_pod_cidr
      or .ipBlock.cidr? == $target_pod_cidr
      or .ipBlock.cidr? == $service_cidr
    )) |
    {
      rule_id: "POD_OR_SERVICE_CIDR",
      namespace, policy, direction, rule,
      message: "Pod or Service CIDR peer requires a selector peer in the same rule"
    }
  '
}

check_dns_pair() {
  # Screen expected peer patterns, not selector coverage or combined policies.
  # shellcheck disable=SC2016 # Variables belong to jq, not the shell.
  append_findings '
    select(.direction == "egress") |
    any(.peers[];
      .namespaceSelector.matchLabels?["kubernetes.io/metadata.name"] == "kube-system"
      and .podSelector.matchLabels?["k8s-app"] == "kube-dns"
    ) as $has_dns_selector |
    any(.peers[]; .ipBlock.cidr? == ($dns_ip + "/32")) as $has_dns_ip |
    select($has_dns_selector != $has_dns_ip) |
    {
      rule_id: "DNS_PAIR",
      namespace, policy, direction, rule,
      message: "Review DNS pairing: include kube-dns selector and exact DNS Service IP peers in the same rule"
    }
  '
}

print_result() {
  if ! jq -s '
    {
      status: (if length == 0 then "CLEAN" else "FINDINGS" end),
      findings: .
    }
  ' "${findings_file}"; then
    assessment_error "unable to produce assessment result"
  fi
  [[ ! -s "${findings_file}" ]]
}

configure_inputs
validate_inputs
create_workspace
fetch_policies
normalize_rules
check_world_cidrs
check_internal_cidrs
check_dns_pair
print_result
