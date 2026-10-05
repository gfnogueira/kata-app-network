#!/usr/bin/env bash
# Run a netshoot command inside another container's network namespace.
# Usage: scripts/netns.sh <container> <cmd...>
set -euo pipefail
target="$1"; shift
docker run --rm -it --network "container:${target}" \
  --cap-add NET_ADMIN --cap-add NET_RAW \
  nicolaka/netshoot:v0.13 "$@"
