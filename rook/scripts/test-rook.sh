#!/bin/bash

set -uo pipefail

LOGGING=${2:-false}
SUCCESSES=0
FAILURES=0
DEBUG_OUTPUT=("")
CONFIG_FILE="${CK8S_CONFIG_PATH}/rook/values.yaml"
here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=rook/scripts/funcs.sh
source "${here}/funcs.sh"

# Args:
#   1. Name of cephcluster
function testCephCluster {
  jsonData=$(kubectl -n rook-ceph get cephclusters.ceph.rook.io "${1}" -ojson)
  health=$(echo "${jsonData}" | jq -r '.status.ceph.health')
  phase=$(echo "${jsonData}" | jq -r '.status.phase')
  if [[ ! $health = "HEALTH_OK" ]]; then
    echo "Cluster health is not ok: $health ❌"; FAILURES=$((FAILURES+1))
    DEBUG_OUTPUT+=("$(echo "${jsonData}" | jq '.status.ceph.details')")
  else
    echo "Cluster health is ok ✔"; SUCCESSES=$((SUCCESSES+1))
  fi
  if [[ ! $phase = "Ready" ]]; then
    echo "Cluster phase is not ready: $phase ❌"; FAILURES=$((FAILURES+1))
  else
    echo "Cluster phase is ready ✔"; SUCCESSES=$((SUCCESSES+1))
  fi
}

# Args:
#   1. jsonData
#   2. cluster
function testOSDs {
  numberOfOSDs=$(kubectl -n rook-ceph get deployments.apps -o=name | grep -c rook-ceph-osd)
  numberOfStorageNodes=$(kubectl get nodes -o=name | grep -cP "storage-\d+$")
  osdDeployments=()
  read -r -d '' -a osdDeployments <<< "$(kubectl -n rook-ceph get deployments.apps -o=json | jq -r '.items[].metadata.name' | grep "rook-ceph-osd")"
  if [[ ! "$numberOfStorageNodes" -gt 0 ]]; then
    numberOfStorageNodes=$(kubectl get nodes -o=name | grep -cP "worker-\d+$")
  fi
  if [[ ! $numberOfStorageNodes = "$numberOfOSDs" ]]; then
    echo "${numberOfOSDs}/${numberOfStorageNodes} deployments exist ❌"; FAILURES=$((FAILURES+1))
  else
    echo "${numberOfOSDs}/${numberOfStorageNodes} deployments exist ✔"; SUCCESSES=$((SUCCESSES+1))
  fi
  for osd in "${osdDeployments[@]}"; do
    echo -n "$osd"
    resourceReplicaCompare "Deployment" "rook-ceph" "${osd}" "${1}" "${2}"
  done
}

# Args:
#   1. jsonData
#   2. cluster
function testMons {
  numberOfMons=$(kubectl -n rook-ceph get deployments.apps -o=name | grep -c rook-ceph-mon)
  numberOfMonsDesired=$(yq4 ".commons.mon.count" "$CONFIG_FILE")
  monDeployments=()
  read -r -d '' -a monDeployments <<< "$(kubectl -n rook-ceph get deployments.apps -o=json | jq -r '.items[].metadata.name' | grep "rook-ceph-mon")"
  if [[ -z $numberOfMonsDesired || $numberOfMonsDesired = "null" ]]; then
    numberOfMonsDesired=$(yq4 ".cephClusterSpec.mon.count" "${here}/../helmfile.d/upstream/rook-ceph-cluster/values.yaml")
  fi
  if [[ ! $numberOfMons = "$numberOfMonsDesired" ]]; then
    echo "${numberOfMons}/${numberOfMonsDesired} deployments exist ❌"; FAILURES=$((FAILURES+1))
  else
    echo "${numberOfMons}/${numberOfMonsDesired} deployments exist ✔"; SUCCESSES=$((SUCCESSES+1))
  fi
  for mon in "${monDeployments[@]}"; do
    echo -n "$mon"
    resourceReplicaCompare "Deployment" "rook-ceph" "${mon}" "${1}" "${2}"
  done
}

# Args:
#   1. jsonData
#   2. cluster
function testMgrs {
  numberOfMgrs=$(kubectl -n rook-ceph get deployments.apps -o=name | grep -c rook-ceph-mgr)
  numberOfMgrsDesired=$(yq4 ".commons.mgr.count" "$CONFIG_FILE")
  mgrDeployments=()
  read -r -d '' -a mgrDeployments <<< "$(kubectl -n rook-ceph get deployments.apps -o=json | jq -r '.items[].metadata.name' | grep "rook-ceph-mgr")"
  if [[ -z "$numberOfMgrsDesired" || "$numberOfMgrsDesired" = "null" ]]; then
    if [[ "${cluster}" = "sc" ]]; then
      TMP_DIR=$(mktemp -p /tmp -d rook-ceph-test.XXXXXX)
      append_trap "rm -rf ${TMP_DIR}" EXIT
      helmfile -e service write-values --output-file-template "${TMP_DIR}/{{ .State.BaseName }}-{{ .State.AbsPathSHA1 }}/{{ .Release.Name}}.yaml" &> /dev/null
      numberOfMgrsDesired=$(yq4 ".cephClusterSpec.mgr.count" "$(find "${TMP_DIR}"/helmfile-*/ -name "rook-ceph-cluster.yaml")")
    elif [[ "${cluster}" = "wc" ]]; then
      TMP_DIR=$(mktemp -p /tmp -d rook-ceph-test.XXXXXX)
      append_trap "rm -rf ${TMP_DIR}" EXIT
      helmfile -e workload write-values --output-file-template "${TMP_DIR}/{{ .State.BaseName }}-{{ .State.AbsPathSHA1 }}/{{ .Release.Name}}.yaml" &> /dev/null
      numberOfMgrsDesired=$(yq4 ".cephClusterSpec.mgr.count" "$(find "${TMP_DIR}"/helmfile-*/ -name "rook-ceph-cluster.yaml")")
    fi
  fi
  if [[ ! $numberOfMgrs = "$numberOfMgrsDesired" ]]; then
    echo "${numberOfMgrs}/${numberOfMgrsDesired} deployments exist ❌"; FAILURES=$((FAILURES+1))
  else
    echo "${numberOfMgrs}/${numberOfMgrsDesired} deployments exist ✔"; SUCCESSES=$((SUCCESSES+1))
  fi
  for mgr in "${mgrDeployments[@]}"; do
    echo -n "$mgr"
    resourceReplicaCompare "Deployment" "rook-ceph" "${mgr}" "${1}" "${2}"
  done
}

function setExpectedResources {
  DEPLOYMENTS=(
    "csi-rbdplugin-provisioner"
    "rook-ceph-operator"
    "rook-ceph-toolbox"
  )
  DAEMONSETS=(
    "csi-rbdplugin"
  )
  CEPHCLUSTERS=(
    "rook-ceph"
  )
  storageNodes=()
  numberOfStorageNodes=$(kubectl get nodes -o=name | grep -cP "storage-\d+$")
  if [[ ! "$numberOfStorageNodes" -gt 0 ]]; then
    numberOfStorageNodes=$(kubectl get nodes -o=name | grep -cP "worker-\d+$")
    read -r -d '' -a storageNodes <<< "$(kubectl get nodes -o=json | jq -r '.items[].metadata.name' | grep -P "worker-\d+$")"
  else
    read -r -d '' -a storageNodes <<< "$(kubectl get nodes -o=json | jq -r '.items[].metadata.name' | grep -P "storage-\d+$")"
  fi
  for (( i=0; i<numberOfStorageNodes; i++ )); do
    DEPLOYMENTS+=("rook-ceph-crashcollector-${storageNodes[i]}")
    JOBS+=("rook-ceph-osd-prepare-${storageNodes[i]}")
  done
}

function test_rook_help() {
  echo "[Usage]: test-rook.sh <sc|wc|both> [--logging-enabled]" >&2
  exit "${1:-0}"
}

function test_rook() {
  clusters=()
  case "${1}" in
  sc)
    clusters+=("sc")
    ;;
  wc)
    clusters+=("wc")
    ;;
  both)
    clusters+=(
      "sc"
      "wc"
    )
    ;;
  esac

  for cluster in "${clusters[@]}"; do
    if [[ -z "$CK8S_APPS_PIPELINE" ]]; then
      export KUBECONFIG="${CK8S_CONFIG_PATH}/.state/kube_config_${cluster}.yaml"
    fi
    DEPLOYMENTS=()
    DAEMONSETS=()
    JOBS=()
    CEPHCLUSTERS=()
    setExpectedResources

    echo
    echo "Testing rook-ceph in ${cluster}.."
    echo

    echo "Testing Deployments"
    echo "===================="
    simpleData="$(getStatus "Deployment" "rook-ceph")"
    for deployment in "${DEPLOYMENTS[@]}"; do
      testResourceExistenceFast "Deployment" "rook-ceph" "${deployment}" "${simpleData}" "${cluster}"
    done
    echo

    echo "Testing Mons"
    echo "===================="
    testMons "${simpleData}" "${cluster}"
    echo

    echo "Testing Mgrs"
    echo "===================="
    testMgrs "${simpleData}" "${cluster}"
    echo

    echo "Testing OSDs"
    echo "===================="
    testOSDs "${simpleData}" "${cluster}"
    echo

    echo "Testing DaemonSets"
    echo "===================="
    simpleData="$(getStatus "DaemonSet" "rook-ceph")"
    for daemonset in "${DAEMONSETS[@]}"; do
      testResourceExistenceFast "DaemonSet" "rook-ceph" "${daemonset}" "${simpleData}" "${cluster}"
    done
    echo

    echo "Testing Jobs"
    echo -n "===================="
    for job in "${JOBS[@]}"; do
      echo -n -e "\n${job}\t"
      if testResourceExistence job "rook-ceph" "${job}"; then
        testJobStatus "rook-ceph" "${job}" "60s" "${cluster}"
      fi
    done
    echo
    echo

    echo "Testing CephClusters"
    echo "===================="
    for cephCluster in "${CEPHCLUSTERS[@]}"; do
      testCephCluster "${cephCluster}" "${cluster}"
    done
    echo

    echo "Testing ServiceMonitors"
    echo "===================="
    targets=(
      "serviceMonitor/rook-ceph/rook-ceph-mgr/0 1"
    )
    if [[ $cluster = "sc" && $(yq4 ".clusters.service.monitoring.installServiceMonitors" "$CONFIG_FILE") = true ]]; then
      test_targets_retry "svc/kube-prometheus-stack-prometheus" "${targets[@]}"
    elif [[ $cluster = "wc" && $(yq4 ".clusters.workload.monitoring.installServiceMonitors" "$CONFIG_FILE") = true ]]; then
      test_targets_retry "svc/kube-prometheus-stack-prometheus" "${targets[@]}"
    else
      echo "ServiceMontiors not enabled in $cluster - Skipping"
    fi
  done
  echo

  echo "Summary"
  echo "===================="
  echo "Successes: $SUCCESSES Failures: $FAILURES"
  echo
  if [ $FAILURES -gt 0 ] && [ "$LOGGING" == "--logging-enabled" ]; then
    echo "Something failed"
    echo
    echo "Logs from failed test resources"
    echo "==============================="
    echo
    echo "Exists in logs/<sc|wc>/<kind>/<namespace>"
    echo
    echo "Events from failed test resources"
    echo "==============================="
    echo
    echo "Exists in events/<sc|wc>/<kind>/<namespace>"
    echo
    echo "Json output of failed test resources"
    echo "===================================="
    echo
    echo "${DEBUG_OUTPUT[@]}" | jq .
    echo
    echo "Unhealthy/missing prometheus targets"
    echo "===================================="
    echo
    echo "${DEBUG_PROMETHEUS_TARGETS[@]}"
    echo
    exit 1
  elif [ $FAILURES -gt 0 ]; then
    echo "Something failed"
    echo
    echo "Json output of failed test resources"
    echo "===================================="
    echo
    echo "${DEBUG_OUTPUT[@]}" | jq .
    echo
    echo "Unhealthy/missing prometheus targets"
    echo "===================================="
    echo
    echo "${DEBUG_PROMETHEUS_TARGETS[@]}"
    echo
    exit 1
  fi
  echo "All tests succeeded"
}

function main() {
  if [[ ${#} == 0 ]]; then
    test_rook_help 1
  fi
  case "${1}" in
  sc)
    test_rook "sc"
    ;;
  wc)
    test_rook "wc"
    ;;
  both)
    test_rook "both"
    ;;
  --help | -h)
    test_rook_help
    ;;
  *)
    echo "unknown command: $1"
    test_rook_help 1
    ;;
  esac
}

main "$@"
