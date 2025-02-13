#!/bin/bash

set -eo pipefail

SUPPORTED_OS=(18.04) # Add more versions here, separated by spaces

log_error() {
  echo -e "[\e[31mck8s conformance test\e[0m] ${*}" 1>&2
}

# Check for Ubuntu 18.04

validate_OS() {
  IFS='=' read -ra RES <<<"$(grep -w 'ID' </etc/os-release)"
  if [[ "${RES[1]}" != "ubuntu" ]]; then
    log_error "Error: Operating system is not Ubuntu"
  fi

  IFS='=' read -ra RES <<<"$(grep -w 'VERSION_ID' </etc/os-release)"
  if [[ " ${SUPPORTED_OS[*]} " != *"${RES[1]//\"/}"* ]]; then
    log_error "Error: Ubuntu version is not valid (valid versions: ${SUPPORTED_OS[*]})"
  fi
}

# Check if Kubernetes is already set up and running on the machine

check_kubernetes() {
  if ls /etc/kubernetes >/dev/null 2>&1; then
    log_error "Error: /etc/kubernetes already exists"
  fi

  if systemctl is-active --quiet kubelet; then
    log_error "Error: A kubelet is already running"
  fi
}

# Check for internet connection and IPv4 forwarding

check_internet() {
  if ! ping -c 2 8.8.8.8 >/dev/null 2>&1; then
    log_error "Error: No internet connection"
  fi

  if [[ $(/sbin/sysctl net.ipv4.conf.all.forwarding) != "net.ipv4.conf.all.forwarding = 1" ]]; then
    log_error "Error: IPv4 forwarding is not enabled"
  fi
}

validate_OS
check_kubernetes
check_internet
