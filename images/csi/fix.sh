#!/usr/bin/env bash
set -euo pipefail
here="$(dirname "$(readlink -f "${0}")")"
docker build --build-arg=SOURCE="$1" -f "${here}/Dockerfile" -t "ghcr.io/elastisys/${1#registry.k8s.io/}" "${here}"
docker push "ghcr.io/elastisys/${1#registry.k8s.io/}"
