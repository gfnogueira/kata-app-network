#!/usr/bin/env bash
# Scenario 4, latency and loss: tc netem on the backend's eth0.
# Usage: break-latency.sh [delay_ms] [loss_pct]   (default 1000 20)
set -e; cd "$(dirname "$0")/.."
DELAY=${1:-1000}; LOSS=${2:-20}
echo ">> tc netem delay ${DELAY}ms loss ${LOSS}%  (inside kata-backend)"
docker run --rm --network container:kata-backend --cap-add NET_ADMIN nicolaka/netshoot:v0.13 \
  sh -c "tc qdisc replace dev eth0 root netem delay ${DELAY}ms loss ${LOSS}%; tc qdisc show dev eth0"
echo ">> done. make watch | make diagnose"
