#!/usr/bin/env bash
set -e; cd "$(dirname "$0")/.."
echo ">> removing netem from kata-backend"
docker run --rm --network container:kata-backend --cap-add NET_ADMIN nicolaka/netshoot:v0.13 \
  sh -c 'tc qdisc del dev eth0 root 2>/dev/null; tc qdisc show dev eth0'
