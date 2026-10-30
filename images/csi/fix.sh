#!/usr/bin/env bash
set -euo pipefail
docker build --build-arg=SOURCE="$1" -f Containerfile -t "ghcr.io/elastisys/${1#registry.k8s.io/}"
docker push "ghcr.io/elastisys/${1#registry.k8s.io/}"
