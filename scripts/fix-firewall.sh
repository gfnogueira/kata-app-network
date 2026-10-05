#!/usr/bin/env bash
set -e; cd "$(dirname "$0")/.."
echo ">> removing DROP rule from kata-backend"
docker run --rm --network container:kata-backend --cap-add NET_ADMIN nicolaka/netshoot:v0.13 \
  sh -c 'while iptables -D INPUT -p tcp --dport 80 -j DROP 2>/dev/null; do :; done; iptables -S INPUT'
