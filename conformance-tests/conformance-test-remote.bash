#!/bin/bash

if [[ $# -lt 2 ]]; then
  echo "Usage: ./conformance-test-remote.bash USERNAME IP"
  exit 1
fi

USERNAME=$1
IP=$2

scp conformance-test.bash "${USERNAME}@${IP}:~"
ssh "${USERNAME}@${IP}" sudo bash conformance-test.bash
ssh "${USERNAME}@${IP}" rm conformance-test.bash
