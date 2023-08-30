#!/bin/bash
LOGGING=${LOGGING:-false}
PIPELINE=${PIPELINE:-false}
if [[ -z "$PIPELINE" ]]; then
    RETRY_COUNT=6
    RETRY_WAIT=10
else
    RETRY_COUNT=24
    RETRY_WAIT=10
fi

# Args:
#   1. kind
#   2. namespace
#   3. name of resource
function testResourceExistence {
    if kubectl get "$1" -n "$2" "$3" &> /dev/null; then
        echo -n -e "\texists ✔"; SUCCESSES=$((SUCCESSES+1))
        return 0
    else
        echo -n -e "\tmissing ❌"; FAILURES=$((FAILURES+1))
        return 1
    fi
}

# Makes dataset smaller for optimization
# Args:
#   1. kind
#   2. namespace
function getStatus() {
    kind="${1}"
    namespace="${2}"
    jsonData=$(kubectl get "${kind}" -n "${namespace}" -o json)
    lessData=$(echo "${jsonData}" |
        jq '.items[] |
            {kind: .kind , name: .metadata.name , namespace: .metadata.namespace ,
            status: .status.readyReplicas , replicas: .status.replicas ,
            numberReady: .status.numberReady , desiredNumberScheduled: .status.desiredNumberScheduled}')
    echo "${lessData}"
}

# Args:
#   1. kind
#   2. namespace
#   3. name of resource
#   4. jsonData
#   5. cluster
function testResourceExistenceFast {
    kind="${1}"
    namespace="${2}"
    currentResource="${3}"
    simpleData="${4}"
    activeResourceStatus=$(echo "${simpleData}" |
        jq -r --arg name "${currentResource}" --arg namespace "${namespace}" --arg kind "${kind}" '. |
            select(.name==$name and .namespace==$namespace and .kind==$kind) |
            .status')

    echo -n "${currentResource}"
    if [[ -z "${activeResourceStatus}" ]]; then
        echo -n -e "\texists ❌"; FAILURES=$((FAILURES+1))
        echo -e "\tready ❌"; FAILURES=$((FAILURES+1))
    else
        echo -n -e "\texists ✔"
        resourceReplicaCompare "${kind}" "${namespace}" "${currentResource}" "${simpleData}" "${5}"
    fi
}

# This function checks if the amount of replicas for a deployment, daemonset or statefulset are correct
# Args:
#   1. kind
#   2. namespace
#   3. name of resource
#   4. jsonData
#   5. cluster
function resourceReplicaCompare() {
    kind="${1}"
    namespace="${2}"
    resourceName="${3}"
    simpleData="${4}"
    retriesLeft="${RETRY_COUNT}"
    while [[ "${retriesLeft}" -gt 0 ]]; do
        if [[ "${kind}" == "Deployment" || "${kind}" == "StatefulSet" ]]; then
            activeResourceStatus=$(echo "${simpleData}" |
                jq -r --arg name "${resourceName}" --arg kind "${kind}" '. |
                    select(.kind==$kind and .name==$name) |
                    .status')

            desiredResourceStatus=$(echo "${simpleData}" |
                jq -r --arg name "${resourceName}" --arg kind "${kind}" '. |
                    select(.kind==$kind and .name==$name) |
                    .replicas')
        # JSON data structure for daemonsets is different from deployments and statefulsets,
        # can not check amount of replicas in the exact same way
        elif [[ "${kind}" == "DaemonSet" ]]; then
            activeResourceStatus=$(echo "${simpleData}" |
                jq -r --arg name "${resourceName}" --arg kind "${kind}" '. |
                    select(.kind==$kind and .name==$name) |
                    .numberReady')

            desiredResourceStatus=$(echo "${simpleData}" |
                jq -r --arg name "${resourceName}" --arg kind "${kind}" '. |
                    select(.kind==$kind and .name==$name) |
                    .desiredNumberScheduled')
        fi

        if [[ "${activeResourceStatus}" == "${desiredResourceStatus}" ]]; then
            echo -e "\tready ✔"; SUCCESSES=$((SUCCESSES+1))
            if [[ "$LOGGING" == "--logging-enabled" ]]; then
              writeLog "${namespace}" "${resourceName}" "Pod" "${5}"
              writeLog "${namespace}" "${resourceName}" "${kind}" "${5}"
              writeEvent "${namespace}" "${resourceName}" "Pod" "${5}"
            fi
            return
        else
            sleep "${RETRY_WAIT}"
            retriesLeft=$((retriesLeft-1))
            # refresh jsonData
            simpleData="$(getStatus "${kind}" "${namespace}")"
        fi
    done

    echo -e "\tready ❌"; FAILURES=$((FAILURES+1))
    DEBUG_OUTPUT+=$(kubectl get "${kind}" -n "${namespace}" "${resourceName}" -o json)
    if [[  "$LOGGING" == "--logging-enabled" ]]; then
      writeLog "${namespace}" "${resourceName}" "Pod" "${5}"
      writeLog "${namespace}" "${resourceName}" "${kind}" "${5}"
      writeEvent "${namespace}" "${resourceName}" "Pod" "${5}"
    fi
}

# This function is required for statefulsets with update strategy OnDelete
# since `kubectl rollout status` doesn't work for them.
# Args:
#   1. namespace
#   2. name of statefulset
#   3. cluster
function testStatefulsetStatusByPods {
    REPLICAS=$(kubectl get statefulset -n "$1" "$2" -o jsonpath="{.status.replicas}")

    for replica in $(seq 0 $((REPLICAS - 1))); do
        POD_NAME=$2-$replica
        if ! kubectl wait -n "$1" --for=condition=ready pod "$POD_NAME" --timeout=60s > /dev/null; then
            echo -n -e "\tnot ready ❌"; FAILURES=$((FAILURES+1))
            DEBUG_OUTPUT+="$(kubectl get statefulset -n "$1" "$2" -o json)"
            if [[ "$LOGGING" == "--logging-enabled" ]]; then
              writeLog "${1}" "${2}" "Pod" "${3}"
              writeLog "${1}" "${2}" "${kind}" "${3}"
              writeEvent "${1}" "${2}" "Pod" "${3}"
            fi
            return
        fi
    done
    echo -n -e "\tready ✔"; SUCCESSES=$((SUCCESSES+1))
}

# Args:
#   1. namespace
#   2. name of job
#   3. Wait time for job to finish before marking failed
#   4. cluster
function testJobStatus {
    if kubectl wait --for=condition=complete --timeout="$3" -n "$1" job/"$2" > /dev/null; then
      echo -n -e "\tcompleted ✔"; SUCCESSES=$((SUCCESSES+1))
    else
      echo -n -e "\tnot completed ❌"; FAILURES=$((FAILURES+1))
      DEBUG_OUTPUT+=$(kubectl get -n "$1" job "$2" -o json)
    fi
    if [[ "$LOGGING" == "--logging-enabled" ]]; then
      logJob "${1}" "${2}" "${4}"
    fi
}

# Args:
#   1. namespace
#   2. name
#   3. cluster
function logJob {
    writeLog "${1}" "${2}" "Job" "${3}"
    writeEvent "${1}" "${2}" "Job" "${3}"
    writeEvent "${1}" "${2}" "Pod" "${3}"
}

LOGSFOLDER="logs"
EVENTSFOLDER="events"

# This function writes logs to file for specified <kind>
# Args:
#   1. namespace
#   2. name
#   3. kind
#   4. cluster
function writeLog {
    if [[ -z "$PIPELINE" ]]; then
        return
    fi

    NAMESPACE=$1
    NAME=$2
    KIND=$3
    CLUSTER=$4
    NAMES=$(kubectl get "$KIND" -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name | grep "$NAME" | tail -n +1)
    mapfile -t NAMESLIST <<< "$NAMES"

    mkdir -p "./$LOGSFOLDER/$CLUSTER/$KIND/$NAMESPACE"
    for NAME in "${NAMESLIST[@]}"
    do
        FILE="./$LOGSFOLDER/$CLUSTER/$KIND/$NAMESPACE/$NAME.log"
        if [[ ! -f "$FILE" ]]; then
            touch "$FILE"
            kubectl -n "$NAMESPACE" logs "$KIND"/"$NAME" --all-containers=true > "$FILE" 2>&1
        fi
    done
}

# This function writes events to file for specified <kind>
# Args:
#   1. namespace
#   2. name
#   3. kind
#   4. cluster
function writeEvent {
    if [[ -z "$PIPELINE" ]]; then
        return
    fi

    NAMESPACE=$1
    NAME=$2
    KIND=$3
    CLUSTER=$4
    NAMES=$(kubectl get "$KIND" -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name | grep "$NAME" | tail -n +1)
    mapfile -t NAMESLIST <<< "$NAMES"

    mkdir -p "./$EVENTSFOLDER/$CLUSTER/$KIND/$NAMESPACE"
    for NAME in "${NAMESLIST[@]}"
    do
        FILE="./$EVENTSFOLDER/$CLUSTER/$KIND/$NAMESPACE/$NAME.event"
        if [[ ! -f "$FILE" ]]; then
            touch "$FILE"
            DATA=$(kubectl get event -n "${NAMESPACE}" --field-selector involvedObject.kind="${KIND}",involvedObject.name="${NAME}" -o json)
            MESSAGES=$(echo "${DATA}" | jq -r '.items | map(.message) | .[]')
            echo "$MESSAGES" > "$FILE"
        fi
    done
}

# Script that test if prometheus targets exist and are healthy

# Fetch the data set
function getData() {
    jsonData=$(curl --silent 'http://localhost:9090/api/v1/targets')
    # Simplify the data by filtering out parts we do not need
    echo "${jsonData}" |
        jq '.data.activeTargets[] |
            {job: .scrapePool , health: .health, instance: .labels.instance}'
}

# Get the current count of healthy instances.
# Exit code 1 if the current count does not match the desired.
#Args:
#   1. data from prometheus
#   2. target name
#   3. expected target instances
function check_target() {
    data="${1}"
    targetName="${2}"
    desiredInstanceAmount="${3}"

    # Stores the value value of the "instance" key where the
    # "job" key matches the value of the current target being tested
    # The number of healthy instances
    currentInstanceAmount=$(echo "${data}" |
        jq -r --arg target "${targetName}" '. |
            select(.job==$target and .health=="up") |
            .instance' | wc -w)
    if [[ ${currentInstanceAmount} == "${desiredInstanceAmount}" ]]; then
        return 0
    else
        return 1
    fi
}

# Check if the target is healthy and increment SUCCESSES or FAILURES accordingly
#Args:
#   1. data from prometheus
#   2. target name
#   3. expected target instances
function test_target() {
    data="${1}"
    targetName="${2}"
    desiredHealthy="${3}"

    if check_target "${data}" "${targetName}" "${desiredHealthy}" &> /dev/null; then
        echo -e "${targetName}\t✔"; SUCCESSES=$((SUCCESSES+1))
    else
        echo -e "${targetName}\t❌"; FAILURES=$((FAILURES+1))
        DEBUG_PROMETHEUS_TARGETS+=("${targetName}")
    fi
}

function test_targets_retry() {
    prometheusEndpoint="${1}"
    shift
    targets=("${@}")

    {
        # Run port-forward instance as a background process
        kubectl port-forward -n monitoring "${prometheusEndpoint}" 9090 &
        PF_PID=$!
        sleep 3
    } &> /dev/null

    # TODO: Why is this not working?
    # trap 'kill "${PF_PID}"; wait "${PF_PID}" 2>/dev/null' RETURN

    echo -n "Checking targets up to 5 times to avoid flakes..."
    for i in {1..5}
    do
        # Get data from prometheus
        jsonData=$(getData)
        # Print progress
        echo -n " ${i}"
        echo
        # Check all targets
        # If there are failures we need to retry
        failure=0
        for target in "${targets[@]}"
        do
            read -r -a arr <<< "${target}"
            name="${arr[0]}"
            instances="${arr[1]}"
            if ! check_target "${jsonData}" "${name}" "${instances}" &> /dev/null; then
                failure=1
                break
            fi
        done

        # If no failures, we are ready to move on
        if [[ ${failure} -eq 0 ]]; then
            break
        fi
        sleep 10
    done
    kill $PF_PID
    wait $PF_PID
    echo -e "\nRunning tests..."
    # Test all targets
    for target in "${targets[@]}"
    do
        read -r -a arr <<< "${target}"
        name="${arr[0]}"
        instances="${arr[1]}"
        test_target "${jsonData}" "${name}" "${instances}"
    done
}

# Normally a signal handler can only run one command. Use this to be able to
# add multiple traps for a single signal.
append_trap() {
    cmd="${1}"
    signal="${2}"

    if [ "$(trap -p "${signal}")" = "" ]; then
        # shellcheck disable=SC2064
        trap "${cmd}" "${signal}"
        return
    fi

    # shellcheck disable=SC2317
    previous_trap_cmd() { printf '%s\n' "$3"; }

    new_trap() {
        eval "previous_trap_cmd $(trap -p "${signal}")"
        printf '%s\n' "${cmd}"
    }

    # shellcheck disable=SC2064
    trap "$(new_trap)" "${signal}"
}
